-- =============================================================================
-- Migration: 20261107_fix_inventory_deduction.sql
-- Description: Fix Meal Logging Inventory Deduction & RLS Mutation Permissions
-- Scope:
--   1. Re-align RLS policies and table grants on public.fridge_items to permit
--      the SECURITY DEFINER role (postgres, service_role) and authenticated callers
--      to execute SELECT, INSERT, UPDATE, and DELETE mutations safely.
--   2. In public.log_meal_transaction:
--      - Explicitly qualify UPDATE and DELETE mutations with `AND user_id = v_user_id`.
--      - Use RETURNING quantity INTO v_updated_quantity on UPDATE.
--      - Use RETURNING id INTO v_deleted_id on DELETE.
--      - Strictly validate `IF NOT FOUND OR ... IS NULL THEN RAISE EXCEPTION ...`
--        so any zero-row mutation instantly aborts and rolls back the transaction.
--      - Set was_deducted = true ONLY after row mutation is successfully verified.
-- =============================================================================

-- 1. TABLE GRANTS ON public.fridge_items
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fridge_items TO authenticated, service_role, postgres;

-- 2. RE-ALIGN RLS POLICIES ON public.fridge_items FOR SECURITY DEFINER & AUTHENTICATED
DROP POLICY IF EXISTS "Users can view own fridge items" ON public.fridge_items;
CREATE POLICY "Users can view own fridge items"
    ON public.fridge_items FOR SELECT
    TO authenticated, postgres, service_role
    USING (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can insert own fridge items" ON public.fridge_items;
CREATE POLICY "Users can insert own fridge items"
    ON public.fridge_items FOR INSERT
    TO authenticated, postgres, service_role
    WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can update own fridge items" ON public.fridge_items;
CREATE POLICY "Users can update own fridge items"
    ON public.fridge_items FOR UPDATE
    TO authenticated, postgres, service_role
    USING (auth.uid() = user_id OR auth.uid() IS NULL)
    WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can delete own fridge items" ON public.fridge_items;
CREATE POLICY "Users can delete own fridge items"
    ON public.fridge_items FOR DELETE
    TO authenticated, postgres, service_role
    USING (auth.uid() = user_id OR auth.uid() IS NULL);

-- 3. RECREATE public.log_meal_transaction WITH STRICT ROW-MUTATION VERIFICATION
CREATE OR REPLACE FUNCTION public.log_meal_transaction(
    p_idempotency_key TEXT,
    p_meal_name TEXT,
    p_meal_type TEXT,
    p_serving_size TEXT DEFAULT '1 serving',
    p_calories INTEGER DEFAULT NULL,
    p_protein_g INTEGER DEFAULT NULL,
    p_carbs_g INTEGER DEFAULT NULL,
    p_fat_g INTEGER DEFAULT NULL,
    p_fiber_g INTEGER DEFAULT NULL,
    p_is_estimate BOOLEAN DEFAULT true,
    p_nutrition_source TEXT DEFAULT 'ai_estimate',
    p_recipe_id UUID DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_ingredients JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id UUID;
    v_timezone TEXT;
    v_local_date DATE;
    v_target_calories INTEGER;
    v_meal_id UUID;
    v_existing_meal_id UUID;
    v_existing_slot TEXT;
    v_existing_date DATE;
    v_clean_slot TEXT;
    v_has_unknown BOOLEAN;
    v_ing RECORD;
    v_fridge_item RECORD;
    v_unit_calc RECORD;
    v_requested_deduct_qty NUMERIC(10,2);
    v_requested_deduct_unit TEXT;
    v_actual_deduct_qty NUMERIC(10,2);
    v_actual_deduct_unit TEXT;
    v_existing_amount NUMERIC(10,2);
    v_new_quantity NUMERIC(10,2);
    v_updated_quantity NUMERIC(10,2);
    v_deleted_id UUID;
    v_matched_fk_id UUID;
    v_snapshot_id UUID;
    v_was_deducted BOOLEAN;
    v_deduction_status TEXT;
    v_deducted_count INTEGER := 0;
    v_deduction_details JSONB := '[]'::JSONB;
BEGIN
    -- 1. Validate Authenticated Caller
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Caller must be an authenticated user.';
    END IF;

    -- 2. Validate Idempotency Key (Mandatory for transactional safety)
    IF p_idempotency_key IS NULL OR pg_catalog.btrim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'idempotency_key is required for meal logging';
    END IF;

    -- 3. Strict Meal Slot Validation (Null check and no silent fallbacks)
    IF p_meal_type IS NULL OR pg_catalog.btrim(p_meal_type) = '' THEN
        RAISE EXCEPTION 'meal_type is required and cannot be empty.';
    END IF;

    v_clean_slot := pg_catalog.lower(pg_catalog.btrim(p_meal_type));
    IF v_clean_slot NOT IN ('breakfast', 'lunch', 'dinner', 'snack') THEN
        RAISE EXCEPTION 'Invalid meal_type: %. Allowed values are: breakfast, lunch, snack, dinner.', p_meal_type;
    END IF;

    -- 4. Resolve User Timezone & Derive Local Date
    SELECT COALESCE(timezone, 'UTC') INTO v_timezone
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_timezone IS NULL THEN
        v_timezone := 'UTC';
    END IF;

    BEGIN
        v_local_date := (pg_catalog.now() AT TIME ZONE v_timezone)::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_local_date := (pg_catalog.now() AT TIME ZONE 'UTC')::DATE;
    END;

    -- 5. Concurrency-Safe Idempotent Insert using UNIQUE(user_id, idempotency_key)
    INSERT INTO public.meals (
        user_id,
        name,
        meal_type,
        logged_at,
        local_date,
        serving_size,
        calories,
        protein_g,
        carbs_g,
        fat_g,
        fiber_g,
        is_estimate,
        nutrition_source,
        recipe_id,
        image_url,
        idempotency_key,
        created_at
    )
    VALUES (
        v_user_id,
        p_meal_name,
        v_clean_slot,
        pg_catalog.now(),
        v_local_date,
        COALESCE(p_serving_size, '1 serving'),
        p_calories,
        p_protein_g,
        p_carbs_g,
        p_fat_g,
        p_fiber_g,
        COALESCE(p_is_estimate, true),
        COALESCE(p_nutrition_source, 'ai_estimate'),
        p_recipe_id,
        p_image_url,
        p_idempotency_key,
        pg_catalog.now()
    )
    ON CONFLICT (user_id, idempotency_key) DO NOTHING
    RETURNING id INTO v_meal_id;

    -- If no row was inserted, a duplicate concurrent/prior request was detected.
    IF v_meal_id IS NULL THEN
        SELECT m.id, m.meal_type, m.local_date INTO v_existing_meal_id, v_existing_slot, v_existing_date
        FROM public.meals m
        WHERE m.user_id = v_user_id AND m.idempotency_key = p_idempotency_key;

        RETURN pg_catalog.jsonb_build_object(
            'status', 'idempotent_duplicate',
            'already_processed', true,
            'message', 'Meal was already successfully logged with this idempotency key.',
            'meal_id', v_existing_meal_id,
            'local_date', v_existing_date,
            'meal_type', v_existing_slot
        );
    END IF;

    -- 6. Process Ingredients & Execute Inventory Deductions Atomically
    IF p_ingredients IS NOT NULL AND pg_catalog.jsonb_array_length(p_ingredients) > 0 THEN
        FOR v_ing IN SELECT * FROM pg_catalog.jsonb_to_recordset(p_ingredients) AS x(
            name TEXT,
            required_quantity NUMERIC,
            required_unit TEXT,
            matched_fridge_item_id UUID,
            deduct_quantity NUMERIC,
            deduct_unit TEXT,
            do_deduct BOOLEAN
        )
        LOOP
            v_requested_deduct_qty := COALESCE(v_ing.deduct_quantity, v_ing.required_quantity, 0);
            v_requested_deduct_unit := COALESCE(v_ing.deduct_unit, v_ing.required_unit, 'pieces');
            v_matched_fk_id := NULL;
            v_snapshot_id := NULL;
            v_actual_deduct_qty := 0;
            v_actual_deduct_unit := v_requested_deduct_unit;
            v_was_deducted := false;
            v_deduction_status := 'none';

            IF COALESCE(v_ing.do_deduct, false) = true THEN
                -- Explicitly reject non-positive deduction quantities when deduction is requested
                IF v_requested_deduct_qty <= 0 THEN
                    RAISE EXCEPTION 'Requested deduction quantity for ingredient "%" must be strictly positive when do_deduct is true (received: %)', v_ing.name, v_requested_deduct_qty;
                END IF;

                IF v_ing.matched_fridge_item_id IS NOT NULL THEN
                    -- Select with row-lock and strictly verify user ownership
                    SELECT id, quantity, unit INTO v_fridge_item
                    FROM public.fridge_items
                    WHERE id = v_ing.matched_fridge_item_id
                      AND user_id = v_user_id
                    FOR UPDATE;

                    IF FOUND THEN
                        -- Ownership verified: assign verified ID to audit snapshot
                        v_snapshot_id := v_fridge_item.id;
                        v_existing_amount := v_fridge_item.quantity;
                        v_actual_deduct_unit := v_fridge_item.unit;

                        -- Safe handling for zero available stock
                        IF v_existing_amount <= 0.0001 THEN
                            v_was_deducted := false;
                            v_deduction_status := 'no_stock';
                            v_matched_fk_id := v_fridge_item.id;
                            v_actual_deduct_qty := 0;
                        ELSE
                            -- Validate unit compatibility & calculate normalized deduction
                            SELECT * INTO v_unit_calc FROM public.calculate_unit_deduction(
                                v_fridge_item.unit,
                                v_requested_deduct_qty,
                                v_requested_deduct_unit
                            );

                            IF NOT v_unit_calc.is_compatible THEN
                                -- Incompatible units: prevent corruption, record status
                                v_was_deducted := false;
                                v_deduction_status := 'incompatible_unit';
                                v_matched_fk_id := v_fridge_item.id;
                                v_actual_deduct_qty := 0;
                            ELSE
                                v_actual_deduct_qty := v_unit_calc.normalized_deduction;

                                -- Clamp deduction so it never exceeds available stock
                                IF v_actual_deduct_qty > v_existing_amount THEN
                                    v_actual_deduct_qty := v_existing_amount;
                                    v_deduction_status := 'partial';
                                ELSE
                                    v_deduction_status := 'full';
                                END IF;

                                v_new_quantity := v_existing_amount - v_actual_deduct_qty;

                                IF v_new_quantity <= 0.0001 THEN
                                    -- Complete consumption: Remove zero-quantity inventory record
                                    DELETE FROM public.fridge_items
                                    WHERE id = v_fridge_item.id
                                      AND user_id = v_user_id
                                    RETURNING id INTO v_deleted_id;

                                    IF NOT FOUND OR v_deleted_id IS NULL THEN
                                        RAISE EXCEPTION 'Inventory depletion failed: fridge item "%" (ID: %) was locked, but the DELETE mutation affected zero rows. Transaction rolled back.',
                                            v_ing.name, v_fridge_item.id;
                                    END IF;

                                    -- Set matched FK to NULL to satisfy foreign key constraint on deleted row
                                    -- Verified audit reference is preserved in fridge_item_id_snapshot
                                    v_matched_fk_id := NULL;
                                    v_deduction_status := 'depleted_and_deleted';
                                    v_was_deducted := true;
                                    v_deducted_count := v_deducted_count + 1;
                                ELSE
                                    -- Partial consumption: Update remaining quantity
                                    UPDATE public.fridge_items
                                    SET quantity = v_new_quantity,
                                        updated_at = pg_catalog.now()
                                    WHERE id = v_fridge_item.id
                                      AND user_id = v_user_id
                                    RETURNING quantity INTO v_updated_quantity;

                                    IF NOT FOUND OR v_updated_quantity IS NULL THEN
                                        RAISE EXCEPTION 'Inventory deduction failed: fridge item "%" (ID: %) was locked, but the UPDATE mutation affected zero rows. Transaction rolled back.',
                                            v_ing.name, v_fridge_item.id;
                                    END IF;

                                    v_matched_fk_id := v_fridge_item.id;
                                    v_was_deducted := true;
                                    v_deducted_count := v_deducted_count + 1;
                                END IF;
                            END IF;
                        END IF;
                    ELSE
                        -- Not found or belongs to another user: keep snapshot NULL to avoid leaking unverified IDs
                        v_deduction_status := 'not_found';
                        v_snapshot_id := NULL;
                        v_matched_fk_id := NULL;
                        v_actual_deduct_qty := 0;
                        v_was_deducted := false;
                    END IF;
                ELSE
                    -- do_deduct is true but no fridge item specified
                    v_deduction_status := 'not_found';
                    v_snapshot_id := NULL;
                    v_matched_fk_id := NULL;
                    v_actual_deduct_qty := 0;
                    v_was_deducted := false;
                END IF;
            ELSE
                -- do_deduct is false: requirement is recorded without inventory modification
                v_deduction_status := 'none';
                v_snapshot_id := NULL;
                v_matched_fk_id := NULL;
                v_actual_deduct_qty := 0;
                v_was_deducted := false;
            END IF;

            -- Insert audit record into meal_ingredients
            INSERT INTO public.meal_ingredients (
                meal_id,
                name,
                required_quantity,
                required_unit,
                matched_fridge_item_id,
                fridge_item_id_snapshot,
                deducted_quantity,
                deducted_unit,
                was_deducted,
                deduction_status,
                created_at
            )
            VALUES (
                v_meal_id,
                v_ing.name,
                v_ing.required_quantity,
                v_ing.required_unit,
                v_matched_fk_id,
                v_snapshot_id,
                v_actual_deduct_qty,
                v_actual_deduct_unit,
                v_was_deducted,
                v_deduction_status,
                pg_catalog.now()
            );

            v_deduction_details := v_deduction_details || pg_catalog.jsonb_build_object(
                'ingredient', v_ing.name,
                'requested_qty', v_requested_deduct_qty,
                'requested_unit', v_requested_deduct_unit,
                'deducted_qty', v_actual_deduct_qty,
                'deducted_unit', v_actual_deduct_unit,
                'status', v_deduction_status,
                'was_deducted', v_was_deducted
            );
        END LOOP;
    END IF;

    -- 7. Update Daily Nutrition Snapshot
    SELECT COALESCE(target_calories, 2000) INTO v_target_calories
    FROM public.nutrition_goals
    WHERE user_id = v_user_id;

    IF v_target_calories IS NULL THEN
        v_target_calories := 2000;
    END IF;

    v_has_unknown := (
        p_calories IS NULL OR 
        p_protein_g IS NULL OR 
        p_carbs_g IS NULL OR 
        p_fat_g IS NULL OR 
        p_fiber_g IS NULL
    );

    INSERT INTO public.daily_nutrition_snapshots (
        user_id,
        log_date,
        total_calories,
        target_calories,
        protein_g,
        carbs_g,
        fat_g,
        fiber_g,
        meals_logged_count,
        meals_with_unknown_nutrition,
        is_complete,
        updated_at
    )
    VALUES (
        v_user_id,
        v_local_date,
        p_calories,
        v_target_calories,
        p_protein_g,
        p_carbs_g,
        p_fat_g,
        p_fiber_g,
        1,
        CASE WHEN v_has_unknown THEN 1 ELSE 0 END,
        NOT v_has_unknown,
        pg_catalog.now()
    )
    ON CONFLICT (user_id, log_date)
    DO UPDATE SET
        total_calories = CASE 
            WHEN EXCLUDED.total_calories IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.total_calories, 0) + EXCLUDED.total_calories
            ELSE daily_nutrition_snapshots.total_calories
        END,
        protein_g = CASE 
            WHEN EXCLUDED.protein_g IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.protein_g, 0) + EXCLUDED.protein_g
            ELSE daily_nutrition_snapshots.protein_g
        END,
        carbs_g = CASE 
            WHEN EXCLUDED.carbs_g IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.carbs_g, 0) + EXCLUDED.carbs_g
            ELSE daily_nutrition_snapshots.carbs_g
        END,
        fat_g = CASE 
            WHEN EXCLUDED.fat_g IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.fat_g, 0) + EXCLUDED.fat_g
            ELSE daily_nutrition_snapshots.fat_g
        END,
        fiber_g = CASE 
            WHEN EXCLUDED.fiber_g IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.fiber_g, 0) + EXCLUDED.fiber_g
            ELSE daily_nutrition_snapshots.fiber_g
        END,
        meals_logged_count = daily_nutrition_snapshots.meals_logged_count + 1,
        meals_with_unknown_nutrition = daily_nutrition_snapshots.meals_with_unknown_nutrition + (CASE WHEN v_has_unknown THEN 1 ELSE 0 END),
        is_complete = (daily_nutrition_snapshots.is_complete AND NOT v_has_unknown),
        updated_at = pg_catalog.now();

    -- 8. Update Daily Meal Slot Progression
    INSERT INTO public.daily_meal_slots (
        user_id,
        log_date,
        meal_slot,
        status,
        completed_at,
        primary_meal_id,
        created_at,
        updated_at
    )
    VALUES (
        v_user_id,
        v_local_date,
        v_clean_slot,
        'completed',
        pg_catalog.now(),
        v_meal_id,
        pg_catalog.now(),
        pg_catalog.now()
    )
    ON CONFLICT (user_id, log_date, meal_slot)
    DO UPDATE SET
        status = 'completed',
        completed_at = pg_catalog.now(),
        primary_meal_id = COALESCE(daily_meal_slots.primary_meal_id, v_meal_id),
        updated_at = pg_catalog.now();

    -- 9. Post Synchronized In-App Notification
    INSERT INTO public.app_notifications (
        user_id,
        title,
        description,
        type,
        metadata,
        created_at
    )
    VALUES (
        v_user_id,
        'Meal logged',
        'Your ' || v_clean_slot || ' (' || p_meal_name || ') has been added to today''s nutrition.',
        'mealLogged',
        pg_catalog.jsonb_build_object('meal_id', v_meal_id, 'meal_type', v_clean_slot),
        pg_catalog.now()
    );

    RETURN pg_catalog.jsonb_build_object(
        'status', 'success',
        'already_processed', false,
        'meal_id', v_meal_id,
        'local_date', v_local_date,
        'meal_type', v_clean_slot,
        'deductions_applied', v_deducted_count,
        'deduction_details', v_deduction_details
    );
END;
$$;

-- 4. HARDEN SECURITY DEFINER EXECUTE PERMISSIONS
REVOKE ALL ON FUNCTION public.log_meal_transaction(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, TEXT, UUID, TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.log_meal_transaction(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, TEXT, UUID, TEXT, JSONB) FROM anon;
REVOKE ALL ON FUNCTION public.log_meal_transaction(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, TEXT, UUID, TEXT, JSONB) FROM service_role;
GRANT EXECUTE ON FUNCTION public.log_meal_transaction(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, TEXT, UUID, TEXT, JSONB) TO authenticated;

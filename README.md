# 🥗 NutriFridge — Your Smart AI-Powered Kitchen Companion

**Less food waste. Smarter meals. Better nutrition.**

NutriFridge is an AI-powered food inventory and nutrition management application designed to make everyday food decisions smarter and easier. It helps users manage their fridge inventory, discover meals using available ingredients, generate personalized recipes, and track their daily nutrition — all in one place.

With an interactive cooking experience and an AI-powered assistant, NutriFridge transforms the way people organize food, plan meals, and maintain healthier eating habits.

---

## ✨ Key Features

### 🧊 Smart Fridge Inventory
- Organize food items across 11 dedicated categories.
- Track available quantities and expiry information.
- Add, manage, and use ingredients from your digital fridge.
- Keep inventory updated as ingredients are used in meals.

### 🤖 AI-Powered Meal Discovery
- Get personalized meal recommendations based on available inventory.
- Discover recipes without manually searching for ingredients.
- Generate meals using your own selected ingredients.
- Optionally specify a dish you want to prepare.

### 🍳 Interactive Cooking Experience
- Select ingredients directly from your virtual fridge.
- Watch selected ingredients animate into an interactive cooking pan.
- Build your own cooking basket before generating a recipe.
- Explore generated recipes with ingredients, availability information, and cooking instructions.

### 📖 AI Recipe Generation
- Generate recipes based on available ingredients.
- Get ingredient quantities and nutritional information.
- Access step-by-step preparation instructions.
- Discover cooking videos related to suggested recipes.

### 📊 Nutrition & Wellness Tracking
- Track daily calories and macronutrients.
- Monitor protein, carbohydrates, and fat intake.
- View meal history and nutrition trends.
- Explore weekly and monthly nutrition progress.

### 🍽️ Meal Logging
- Log multiple meals across Breakfast, Lunch, Dinner, and other meal slots.
- Track nutritional intake from logged meals.
- Automatically update inventory through the meal-logging transaction.
- Maintain a record of meals and daily nutrition.

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter** | Cross-platform application development |
| **Dart** | Application programming language |
| **Supabase** | Authentication, database, and backend services |
| **Supabase Edge Functions** | Secure server-side API orchestration |
| **n8n** | AI workflow automation and orchestration |
| **Google Gemini API** | AI-powered recipe generation and food-related intelligence |

---


**How it works:**

1. The user interacts with the NutriFridge Flutter application.
2. AI-related requests are securely sent to Supabase Edge Functions.
3. n8n orchestrates the AI workflow and communicates with Google Gemini.
4. Gemini processes the request and generates recommendations or recipe information.
5. The response is returned to the application.
6. Supabase manages persistent inventory, meal records, and nutrition data.

Meal logging and inventory updates use the application's existing database transaction flow to maintain data consistency.

---


## 🎯 Project Vision

NutriFridge aims to make food management more intelligent, accessible, and sustainable.

By combining food inventory management, AI-powered recipe discovery, interactive cooking experiences, and nutrition tracking, the goal is to help users:

- Make better use of ingredients they already have.
- Reduce unnecessary food waste.
- Simplify everyday meal planning.
- Make informed nutritional choices.
- Build healthier and more sustainable food habits.

---

## 🔮 Future Scope

NutriFridge is designed to evolve into a more intelligent kitchen companion, with potential enhancements including:

- Advanced food recognition and image-based inventory management.
- Smart expiry monitoring and food-waste prevention.
- More personalized meal recommendations.
- Automated food-image discovery for ingredients and recipes.
- Enhanced nutrition insights and meal planning.

---

## 💚 Built With

Built with Flutter, Supabase, n8n, and Google Gemini.

**NutriFridge — Your fridge, your ingredients, your smarter meals.**

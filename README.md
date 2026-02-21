# ProfLevelHelper

Profession leveling assistant for WoW Classic (Titan). Helps you choose the cheapest way to level by combining AH prices, vendor prices, and trainer costs for both **materials** and **recipes**.

## Features

- **AH scan**: Stores minimum **unit** price per item (materials and recipe items) for the current realm/faction. Scan logic follows **EasyAuction**: one-shot `AUCTION_ITEM_LIST_UPDATE`, batch processing with configurable `scanPerFrame` (default 100, 50–200 recommended) and 50ms delay between batches to avoid freezing; optional Browse-tab switch; 5s fallback if the event does not fire.
- **Recipe cost**: For each recipe, uses the **minimum** of: AH price (if recipe is an item), NPC vendor price (when you visit a vendor), or trainer learning cost (optional saved data). If you already know the recipe, cost is 0.
- **Skill-up formula**: Uses the standard formula `chance = (gray - current) / (gray - yellow)` (orange = 100%, gray = 0%). When exact thresholds are unknown, falls back to skillType (optimal / easy / medium / trivial).
- **Holiday recipes**: Option to include or exclude holiday/seasonal recipes (default: exclude).
- **Cheapest-first list**: Opens your profession, then shows a list of recipes sorted by expected cost per skill point (materials + recipe acquisition).

## Commands

- `/plh` or `/proflevelhelper` – Show help.
- `/plh scan` – Scan the auction house (run while at the AH). Saves min price per item and name→itemID for materials.
- `/plh list` – Build and show the cheapest leveling list for the **currently open** profession window.
- `/plh options` – Open options (e.g. “Include holiday/seasonal recipes”) and close button.

## Usage

1. Go to the auction house and run `/plh scan`. Wait until the scan finishes.
2. (Optional) Visit recipe vendors or trainers so the addon can record vendor prices (MERCHANT_SHOW) or set trainer costs later.
3. Open your profession (e.g. Engineering), then run `/plh list`. The list shows recipes sorted by cost per skill point, with recipe acquisition cost (AH/vendor/trainer) considered.

## Saved data

- `ProfLevelHelperDB.AHPrices` – itemID → min price (copper).
- `ProfLevelHelperDB.NameToID` – item name → itemID (from AH scan).
- `ProfLevelHelperDB.VendorPrices` – itemID → vendor buy price (filled when you open a merchant).
- `ProfLevelHelperDB.TrainerCosts` – optional spellID/name → cost.
- `ProfLevelHelperDB.IncludeHolidayRecipes` – boolean option.
- `ProfLevelHelperDB.scanPerFrame` – number of AH items processed per batch (default 100; 50–200 like EasyAuction).

## Recipe thresholds (optional)

For accurate skill-up chance, you can add static data:  
`ProfLevelHelper.RecipeThresholds[professionName][recipeName] = { yellow = N, gray = N }` in `RecipeCost.lua` or a separate data file. Without this, the addon uses the skillType fallback (optimal / easy / medium / trivial).

## Interface

30405 (Titan Classic). Requires profession and auction UIs (Blizzard_TradeSkillUI loaded on demand).

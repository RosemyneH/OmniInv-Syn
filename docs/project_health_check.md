# Project Risk & Architecture Analysis

Based on a review of the current codebase (`Core.lua`, `UI/*.lua`, `Omni/*.lua`), here is a critical analysis of the project's risks and architectural state.

### 1. Which parts of the project currently carry the highest risk of errors or regressions?
*   **The Async Item Data Chain**: In `Categorizer.lua`, the function `ClassifyByItemType` relies on `GetItemInfo()`. In WoW (both 3.3.5 and Retail), this function returns `nil` if the item is not in the local cache. Currently, the code defaults these items to *"Miscellaneous"*.
    *   **Risk**: On login or when opening a bank with new items, users will see a screen full of "Miscellaneous" items until they hover over them or trigger an update.
*   **The Custom Rule Engine (`Omni.Rules`)**: The use of `loadstring` (or `load`) to compile custom Lua expressions is powerful but dangerous.
    *   **Risk**: A user can write an infinite loop `while true do end` in a rule condition, freezing the game client. There is currently no timeout or "instruction count" protection in the sandbox.

### 2. If you had to simplify this project without losing functionality, where would you start and why?
*   **Merge View Modes**: You currently have `Grid`, `Flow`, and `List` views. `Grid` is essentially `Flow` with fixed categories (or one large category).
    *   **Action**: Deprecate specific view logic files and make "Grid" just a Flow view where every item is forced into a single "Bag" category. This reduces layout calculation code by ~40%.
*   **Unify Bag/Bank Backend**: `Frame.lua` has separate logic branches for `bags` vs `bank` in `UpdateLayout`.
    *   **Action**: Abstract `GetItems(containerType)` into `Omni.API`. The UI should not care if it's iterating over Bag IDs 0-4 or Bank IDs -1...N.

### 3. Which problems are not visible yet but will appear as the project grows?
*   **Performance Bottleneck (O(N*M))**: In `UpdateLayout`, for *every* item (N), the code iterates through *every* rule (M) via `Categorizer:GetCategory` -> `Rules:FindMatchingRule`.
    *   **Future Issue**: As users add 50+ custom rules and have 200+ items (Retail banks), the frame rate will hitch noticeably whenever a bag opens or item updates.
*   **Memory Fragmentation**: `CategoryEditor.lua` and `ItemButton.lua` create new frames/textures dynamically. While `ItemButton` supports pooling, if the pool isn't aggressively managed, opening/closing the UI repeatedly could bloat memory usage over long sessions.

### 4. Which current technical decisions limit scalability or maintainability?
*   **Global `Omni` Namespace Coupling**: Almost every generic module (e.g., `Categorizer`, `Rules`) is coupled to `Omni.Data` or `OmniInventoryDB`.
    *   **Limit**: You cannot easily reuse 'Rules' in another addon or test it in isolation because it expects the specific global DB structure of this project.
*   **Hardcoded UI Positioning**: `UI/CategoryEditor.lua` and others uses manual `SetPoint` relative calculations.
    *   **Limit**: Adding a new UI element (like a search filter checkbox) requires manually recalculating unrelated pixel offsets, making UI iterations slow.

### 5. Which parts of the code or architecture should be isolated, documented, or tested first?
*   **`Omni/API.lua` (The Shim Layer)**: This is the bridge between WotLK and Retail.
    *   **Why**: If this breaks, the addon fails completely. It should be documented explicitly: "Input: WotLK API, Output: Retail-like Table Structure."
*   **`Omni/Rules.lua`**:
    *   **Why**: This contains complex boolean logic parsing. It is the mostly likely place for "logic bugs" (e.g. "Does 'CONTAINS' match case-sensitively?"). Unit tests here would be high value.

### 6. Where can the project’s actual behavior diverge from the developer’s original intent?
*   **Item Sorting Stability**: Lua's `table.sort` is not stable.
    *   **Divergence**: Items to jump around randomly when their sort priority is equal (e.g., two Hearthstones). This feels "glitchy" to users.
*   **Event Handling**: `BAG_UPDATE` fires multiple times per second when looting.
    *   **Divergence**: Although `Omni/Events.lua` uses bucketing, if the bucketing timer is too short (e.g. 0.05s) vs the render time (0.1s due to rule processing), the UI will feel sluggish or unresponsive during combat looting.

### 7. Which patterns, abstractions, or conventions could reduce overall complexity?
*   **Reactive Data Model (Observer Pattern)**: Instead of `Frame.lua` asking "Give me all items, now categorize them, now sort them", the Data layer should emit signals: `InventoryChanged` -> `CategorizerUpdates` -> `UI_Render`.
*   **Item Mixins**: Instead of raw tables for items, use a metatable wrapper `Item:New(id)`. Logic like `item:IsJunk()` or `item:GetIcon()` belongs on the item object, clearing clutter from `Frame.lua`.

### 8. If someone else had to take over this project tomorrow, what would cause problems first?
*   **The "Magic" Sandbox**: A new dev looking at `Rules.lua` might not understand how `setfenv` is being used to prevent global access while allowing math functions.
*   **API Versioning**: Without clear comments on which functions are 3.3.5a vs Retail (in `API.lua`), a dev might "fix" a function for Retail that breaks Classic, or vice versa.

### 9. Which improvements would deliver the best impact-to-effort ratio in the short term?
*   **Handle `GET_ITEM_INFO_RECEIVED`**: Add an event listener to `Omni/Events.lua` that triggers a simplified "Update Cache" call. This solves the "Miscellaneous" item bug with about 10 lines of code.
*   **Visual Feedback for Rules**: In the Category Editor, add a simple text label: "Matches X items in your bags". It instantly tells the user if their rule works.

### 10. What currently prevents this project from reaching a “production-robust” level?
*   **No Localization (L10n)**: All strings ("Category Editor", "Sell Junk") are hardcoded in English.
*   **Error Boundaries**: A single Lua error in a render loop (e.g., a bad texture ID) will stop the entire bag frame from rendering. `pcall` should wrap the row rendering in `FlowView` and `GridView`.

# Combat AI Strategist update notes

## Version 1.7.4

### Responsive AI thinking

- Removed the global SceneTree pause from AI-vs-AI thinking.
- Pause, menus, and normal interface controls remain available while the AI searches.
- AI-vs-AI still calculates across frames and synchronously replaces any premature Wait before advancing the turn.
- Manual game pause now pauses the AI brain with the rest of the match.

## Version 1.7.3

### Thinking display and performance

- Restored frame-sliced AI-vs-AI thinking controlled by Patience Mode.
- Restored the visible `Combat AI is thinking...` status and simulation counter while searching.
- The live match is held during AI-vs-AI search so it cannot lock in Wait before a decision finishes.
- The previous game pause state is restored after both AI choices are submitted.

## Version 1.7.2

### Miko compatibility

- Added support for Miko's held Sword and Spell charge inputs.
- Miko now evaluates both charge paths even when her large move list uses the normal search budget.
- Once charging Sword or Spell, the AI keeps holding that path until the charge is spent instead of resetting it by switching.
- Added value for Miko's Sword and Spell charge levels so their unlocked moves can enter normal move selection.

## Version 1.7.1

### AI-vs-AI hotfix

- Fixed AI-vs-AI repeatedly locking in Wait before a simulated decision finished.
- AI-vs-AI now completes each side's search before submitting its move.
- Solo AI still divides long searches across frames.

### Custom dialogues

- The dialogue folder and `custom_dialogues.json` are created when needed.
- Dialogue files remain separate from the Workshop archive and are never overwritten.
- The folder, file, and reload buttons remain in Mod Options.

### Installation

- Removed the automatic patcher and patch guide.
- Install updates by replacing the mod ZIP or by letting Steam replace the subscribed Workshop item, then restart the game.
- Existing settings and dialogue JSON files are left unchanged.

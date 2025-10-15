# Switchboard Interact Action

## Package Information

- **Name:** jivas/switchboard_interact_action
- **Author:** V75 Inc.
- **Archetype:** SwitchboardInteractAction
- **Version:** 0.1.0

## Meta Information

- **Title:** Switchboard Interact Action
- **Description:** Manages and Routes users to their subscribed agents, ensuring smooth transitions and consistent communication.
- **Type:** interact_action
- **Group:** core

## Configuration

- **Singleton:** true
- **Order:**
  - **Before:** jivas/persona_interact_action
  - **Weight:** -10

## Dependencies

- **Jivas:** ~2.1.0
- **Actions:**
  - jivas/persona_interact_action: ~0.1.0

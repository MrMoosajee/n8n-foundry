# n8n Foundry (v3)

This repository encapsulates the core components and architectural blueprint for the n8n Foundry system, specifically focusing on its third iteration (v3). It integrates various workflows and database schemas designed to orchestrate complex, AI-driven processes, likely pertaining to software development or project management.

## The Constraint

The primary challenge addressed by this project was the need to consolidate disparate n8n workflow components into a single, robust, and bug-free JSON definition. Previous iterations suffered from issues like race conditions, redundant data handling, and unclear architectural separation across multiple project parts. The objective was to create a reliable n8n framework capable of autonomously managing complex, multi-stage processes while maintaining data integrity and operational stability.

## The Implementation

The `n8n Foundry` v3 implements a streamlined and robust architecture, detailed across its components:
*   **`foundry_v3_init_db.sql`**: Defines the foundational PostgreSQL schema required for the n8n workflows, ensuring data integrity and consistency.
*   **`foundry_v3_prompt_master_workflow.json`**: An n8n workflow specifically designed for prompt engineering and managing the initial stages of AI-driven tasks.
*   **`foundry_v3_software_dev_lead_workflow.json`**: An n8n workflow that orchestrates the software development aspects, likely integrating with various tools and processes.
*   **`FOUNDRY_V3_IMPLEMENTATION_SUMMARY.md`**: Provides a high-level overview of the v3 implementation details.
*   **`FOUNDRY_V3_SETUP_GUIDE.md`**: Offers instructions for setting up and configuring the n8n Foundry system.

Key architectural improvements, as outlined in the `Phoenix Build Plan`, include:
*   Utilizing a single `Code` node for blueprint preparation and a single `Postgres` node for atomic, reliable insertion to prevent bugs and improve efficiency.
*   Implementation of `Limit` nodes to prevent race conditions in critical status update and logging steps.
*   Strict use of explicit node references (e.g., `{{ $node["Parse Architecture"].json.project_id }}`) for reliable data fetching, addressing a critical hotfix.

## The Outcome

The `n8n Foundry` v3 represents a significant leap in stability and efficiency for automated, AI-orchestrated processes. By consolidating workflows, eliminating bugs related to race conditions and data handling, and adhering to a robust architectural design, the system achieves:
*   **Enhanced Reliability**: Workflows execute consistently without unexpected failures.
*   **Improved Maintainability**: A modular and consolidated structure makes the system easier to understand, debug, and extend.
*   **Clear Process Orchestration**: Distinct workflows for roles like 'Prompt Master' and 'Software Dev Lead' ensure clear separation of concerns and efficient task flow.
*   **Foundational Stability**: A well-defined database schema and rigorous bug fixes provide a solid platform for future AI-native systems development.

This iteration effectively transforms a complex, bug-prone system into a coherent and dependable operational framework.
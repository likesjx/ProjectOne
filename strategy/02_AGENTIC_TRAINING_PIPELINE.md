# Agentic Training Pipeline with LangGraph

To automate our MLOps lifecycle, we will implement a server-side "AI Model Trainer" agent using LangGraph. This agent will manage the entire process of fine-tuning our speech models with user-submitted data.

## 1. Agent State

The agent's operation will be coordinated through a central `State` object that is passed between nodes. This object tracks the progress and artifacts of the training job.

```python
# Conceptual LangGraph State
class TrainingGraphState:
    batch_id: str              # Unique identifier for the training batch
    raw_data_path: str         # Path to the uploaded user data (e.g., a .zip file)
    processed_data_path: str   # Path to the cleaned, validated data
    base_model_version: str    # The version/commit of the model we are fine-tuning
    new_model_path: str        # Path to the newly trained model artifact
    evaluation_metrics: dict   # Dictionary holding performance metrics (e.g., {"wer": 0.15})
    is_new_model_better: bool  # Flag indicating if the new model passed evaluation
    deployment_status: str     # Final status (e.g., "SUCCESS", "FAILED_EVALUATION")
```

## 2. Graph Nodes (Agent's Tools)

Each step in the pipeline is a node that performs a specific task.

1.  **`Data Ingestion & Validation Node`**
    *   **Input:** `raw_data_path`
    *   **Action:** Unzips and validates the incoming user data. It discards corrupted files, silent audio, or empty transcripts to ensure data quality.
    *   **Output:** Updates state with `processed_data_path`.

2.  **`Model Fine-Tuning Node`**
    *   **Input:** `processed_data_path`, `base_model_version`
    *   **Action:** Executes the core MLX Python training script. This node is responsible for managing the potentially long-running fine-tuning process, capturing logs, and handling errors.
    *   **Output:** Updates state with `new_model_path`.

3.  **`Model Evaluation Node`**
    *   **Input:** `new_model_path`
    *   **Action:** Runs the new model against a curated, high-quality "golden dataset" to calculate its Word Error Rate (WER) and other relevant metrics. It compares these metrics against the performance of the current production model.
    *   **Output:** Updates state with `evaluation_metrics` and `is_new_model_better`.

4.  **`Deploy Model Node`**
    *   **Input:** `new_model_path`, `evaluation_metrics`
    *   **Action:** This node is triggered only if `is_new_model_better` is `True`. It uses the `huggingface_hub` library to upload the new model files and a descriptive Model Card to our private Hugging Face repository. It creates a new commit with a tag for versioning.
    *   **Output:** Updates state with `deployment_status: "SUCCESS"`.

5.  **`Quarantine & Notify Node`**
    *   **Input:** The final state of a failed run.
    *   **Action:** This node is the failure path. It saves the failed model, its data, and logs to a "quarantine" directory for manual inspection. It then sends an alert (e.g., via Slack or email) to the development team.
    *   **Output:** Updates state with `deployment_status: "FAILED_EVALUATION"` or `"ERROR"`.

## 3. Graph Flow (Agent's Logic)

The nodes are connected with edges that define the agent's workflow.

-   **Start** -> `Data Ingestion & Validation`
-   `Data Ingestion & Validation` -> `Model Fine-Tuning`
-   `Model Fine-Tuning` -> `Model Evaluation`
-   `Model Evaluation` -> **Conditional Edge**:
    -   If `is_new_model_better` is `True` -> `Deploy Model`
    -   If `is_new_model_better` is `False` -> `Quarantine & Notify`
-   `Deploy Model` -> **End**
-   `Quarantine & Notify` -> **End**

This agentic workflow provides a robust, automated, and observable system for continuously improving our AI models, forming the core of our MLOps strategy.

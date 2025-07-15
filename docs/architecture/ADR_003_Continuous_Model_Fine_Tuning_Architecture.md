# ADR-003: Continuous Model Fine-Tuning Architecture

**Status:** Proposed

**Date:** 2025-07-14

## Context

The default WhisperKit model provides excellent general-purpose transcription. However, to achieve state-of-the-art accuracy for our specific domain and user base, the model must be adapted over time. Users will inevitably encounter transcription errors, especially with niche terminology, regional accents, or in noisy environments. 

Providing a mechanism for users to correct these errors and for the system to learn from them is a critical feature for improving long-term product quality, user retention, and building a competitive advantage.

## Decision

We will implement a closed-loop, "human-in-the-loop" fine-tuning architecture. This system will allow the application to continuously improve its transcription accuracy by collecting user corrections, retraining the speech-to-text model on a recurring basis, and deploying the updated model back to the users' devices dynamically.

The architecture is divided into four distinct phases:

### Phase 1: In-App Data Collection

1.  **Correction Interface:** A UI will be provided (likely enhancing `TranscriptionCorrectionView`) that allows users to easily edit and save corrected transcripts for their audio recordings.
2.  **Data Persistence:** A new SwiftData model, `FineTuningDataPoint`, will be created to store the relationship between an audio recording (`RecordingItem`) and its user-provided `correctedTranscription`. Each entry will be marked with an `uploaded` flag to manage the upload queue.
    ```swift
    @Model
    final class FineTuningDataPoint {
        @Attribute(.unique) var id: UUID
        var recordingItemID: UUID // Foreign key to the RecordingItem
        var correctedTranscription: String
        var timestamp: Date
        var uploaded: Bool

        init(id: UUID = .init(), recordingItemID: UUID, correctedTranscription: String) {
            self.id = id
            self.recordingItemID = recordingItemID
            self.correctedTranscription = correctedTranscription
            self.timestamp = .now
            self.uploaded = false
        }
    }
    ```
3.  **Secure Batch Upload:** A background service within the app will periodically batch the new, non-uploaded correction data (the audio file snippet and its corrected text) and securely upload it to a dedicated backend service.
4.  **User Consent:** The app must include a clear and explicit user consent flow for opting into this data collection for model training purposes. This is a critical privacy and legal requirement.

### Phase 2: Backend Training Pipeline

1.  **API Endpoint:** A secure backend service (e.g., a Python server using FastAPI) will expose an endpoint (e.g., `/upload-training-data`) to receive and store the training data.
2.  **Data Lake:** Uploaded data will be aggregated in a cloud storage bucket (e.g., AWS S3 or Google Cloud Storage), forming a comprehensive, high-quality dataset for fine-tuning.
3.  **Automated Fine-Tuning:** We will leverage the Hugging Face ecosystem for the training process:
    *   **Mechanism:** Use Hugging Face AutoTrain for a no-code solution or custom `transformers` training scripts for more control.
    *   **Process:** A recurring job (e.g., weekly or bi-weekly) will be triggered. It will:
        a. Pull the latest training dataset from the cloud storage bucket.
        b. Load the *previous* fine-tuned model from a private Hugging Face Hub repository.
        c. Continue training (fine-tune) the model on the new data.
        d. Push the newly updated model version back to the Hugging Face Hub repository.

### Phase 3: Automated Model Conversion & Deployment

1.  **CI/CD for Model Conversion:** A CI/CD pipeline (e.g., using GitHub Actions) will be configured to trigger on every new push to the Hugging Face model repository.
2.  **Conversion to CoreML:** The pipeline will execute a Python script that:
    a. Downloads the latest fine-tuned model from Hugging Face.
    b. Uses Apple's `coremltools` package to convert the model to the compiled CoreML format (`.mlmodelc`).
    c. Packages the compiled CoreML model into a `.zip` archive for efficient transfer.
3.  **Deployment to CDN:** The zipped CoreML model is uploaded to a Content Delivery Network (CDN) or cloud storage for fast and reliable global distribution to user devices.

### Phase 4: In-App Dynamic Model Update

1.  **Model Versioning API:** The backend will provide a simple endpoint (e.g., `/latest-model-info`) that returns the latest model's version string and its download URL.
    ```json
    {
      "version": "1.2.1",
      "url": "https://cdn.our-service.com/models/whisper-finetuned-v1.2.1.zip"
    }
    ```
2.  **In-App Update Check:** On launch or at regular intervals, the app will call this endpoint and compare the server's model version with the version it currently has stored locally.
3.  **Download & Replace:** If a newer version is available, the app will download the zipped model from the URL, unpack it, and atomically replace the existing model in its Application Support directory.
4.  **Dynamic Loading:** The `WhisperKitTranscriber` service will be modified to load the model from this specific file path, ensuring it uses the latest fine-tuned version on its next initialization.

## Consequences

### Benefits
*   The transcription model will become progressively more accurate over time, directly addressing user-identified errors and adapting to their specific use cases.
*   User engagement and trust are increased as they see their corrections lead to tangible product improvements.
*   Creates a significant competitive advantage by building a proprietary, highly-adapted AI model that is difficult for competitors to replicate.

### Costs & Risks
*   **New Infrastructure:** Requires building and maintaining a backend service, a data storage solution, and a robust training pipeline.
*   **Data Privacy & Security:** Requires rigorous processes for handling sensitive user voice data, including obtaining explicit consent and ensuring secure, anonymized storage and transmission.
*   **Increased Complexity:** Adds significant complexity to the overall system architecture, requiring expertise in backend development, MLOps, and CI/CD.
*   **Operational Costs:** Cloud storage, compute resources for training, and CDN bandwidth will incur ongoing operational costs that need to be managed.

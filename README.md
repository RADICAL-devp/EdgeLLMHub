# 🏥 dev-playground: Clinical Intelligence & Utilities

<p align="center">
  A multi-project monorepo housing the <b>Clinical Intelligence API</b>, a high-performance healthcare engine powered by <b>Micronaut</b>, <b>LangChain4J</b>, and <b>Google Cloud AI</b>.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Java-17%2B-blue.svg" />
  <img src="https://img.shields.io/badge/Micronaut-4.x-success" />
  <img src="https://img.shields.io/badge/LangChain4j-1.0.0-orange" />
  <img src="https://img.shields.io/badge/Status-Active%20Development-success" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/java/java-original.svg" width="50" />
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/gradle/gradle-original.svg" width="50" />
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/googlecloud/googlecloud-original.svg" width="50" />
</p>

**Core Technologies**
- **Java 17+** & **Gradle** (Multi-project setup with Gradle init conventions)
- **Micronaut** — High-performance, reactive microservices framework
- **LangChain4j** — LLM orchestration and local embeddings (All-MiniLM-L6-v2)
- **Qdrant** — Production-grade persistent vector database for semantic search
- **Google Cloud Speech-to-Text V2 (Chirp)** — Advanced transcription for regional languages
- **Google Cloud Translate V3** — Regional language to English translation

---

## 📑 Table of Contents
- [Overview](#-overview)
- [Architecture & Pipeline](#-architecture--pipeline)
- [Project Structure](#-project-structure)
- [Installation & Setup](#-installation--setup)
- [Testing](#-testing)

---

## 🔬 Overview

This repository acts as the core backend monorepo, with its flagship application being the **Clinical Intelligence API** (`clinical-intelligence`). It acts as a comprehensive pipeline to process, transcribe, translate, and semantically analyze clinical artifacts such as:
- **Doctor Consultation Notes**
- **Medical Reports**
- **Sleep Study Results**
- **Audio Transcriptions**

By combining reactive endpoints (Project Reactor) with state-of-the-art LLM capabilities, this repository aims to streamline healthcare data processing, extract structured information, and provide vector-based search across medical records.

---

## ⚙️ Architecture & Pipeline

The Clinical Intelligence pipeline processes raw clinical inputs into structured, vector-searchable summaries using a tightly coupled four-phase process.

```text
Raw Clinical Input (Audio / Regional Text)
        │
        ▼
┌──────────────────────────────────────────────┐
│  Phase 1 — Ingestion & Transcription         │
│  Google Cloud Speech-to-Text (Chirp model)   │
└──────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────┐
│  Phase 2 — Translation                       │
│  Google Cloud Translate V3 (To English)      │
└──────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────┐
│  Phase 3 — LLM Structuring                   │
│  LangChain4j + OpenAI / Local Models         │
│  Extract: Symptoms, Diagnosis, Prescriptions │
└──────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────┐
│  Phase 4 — Vectorization                     │
│  All-MiniLM-L6-v2 + Qdrant                   │
│  Semantic indexing for clinical queries      │
└──────────────────────────────────────────────┘
        │
        ▼
  Structured Clinical Summary
```

---

## 📂 Project Structure

This is a Gradle multi-project build composed of applications and shared libraries:

- `projects/apps/clinical-intelligence/`
  - Core AI/Healthcare microservice utilizing Micronaut, LangChain4j, and GCP.
- `projects/apps/app/`
  - Standard Java application sandbox.
- `projects/libs/utilities/`
  - Shared utility functions, text processing, and helpers.
- `projects/libs/list/`
  - Custom data structures and domain models.

---

## 🚀 Installation & Setup

### Prerequisites
- **JDK 17** or higher
- **Docker & Docker Compose** (for running the local Qdrant vector database)
- **Google Cloud Service Account credentials** (for Speech-to-Text and Translation APIs)
- **OpenAI API Key** (for LangChain4j LLM integration)

### Get Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/dev-playground.git
   cd dev-playground
   ```

2. **Start infrastructure dependencies**
   The `clinical-intelligence` app requires a Qdrant vector database instance.
   ```bash
   cd projects/apps/clinical-intelligence
   docker-compose up -d
   cd ../../../
   ```

3. **Build the projects**
   We use the Gradle wrapper to ensure consistent builds across environments.
   ```bash
   ./gradlew build
   ```

4. **Run the Clinical Intelligence API**
   ```bash
   ./gradlew :clinical-intelligence:run
   ```

---

## 🧪 Testing

The repository relies on JUnit 5 and Mockito for robust test coverage.

Run all tests across the monorepo:
```bash
./gradlew test
```

To test a specific module (e.g., `clinical-intelligence`):
```bash
./gradlew :clinical-intelligence:test
```

class LLMConfig {
  static const String modelPath = 'Qwen3-0.6B-Q4_K_M-MLC';
  static const String modelId = 'Qwen3-0.6B-Q4_K_M-MLC';
  static const int contextLength = 2048;
  // SHA-256 of qwen3-0.6b-Q4_K_M.zip built from ios/mlc-llm/Qwen3-0.6B-Q4_K_M-MLC
  // on 2026-09-30 (local `zip -r -X`, 283M, true Qwen3-0.6B-q4f16_1 9-shard
  // bundle). Re-hash the actually uploaded artifact — plain `zip -r` (CI)
  // embeds different metadata and changes this.
  static const String modelChecksum =
      '447145d7dbb9ee2fc9047e3cfa64ef4a324397e8208580c7348e5c4002ed8c83';
}

class QueueState {
  const QueueState({
    required this.isUploading,
    required this.currentFile,
    required this.statusLabel,
    required this.progressPercentage,
    required this.completedFiles,
    required this.totalFiles,
    required this.isPaused,
    this.lastError,
  });

  const QueueState.idle()
    : isUploading = false,
      currentFile = null,
      statusLabel = 'Vault queue is idle',
      progressPercentage = 0,
      completedFiles = 0,
      totalFiles = 0,
      isPaused = false,
      lastError = null;

  final bool isUploading;
  final String? currentFile;
  final String statusLabel;
  final double progressPercentage;
  final int completedFiles;
  final int totalFiles;
  final bool isPaused;
  final String? lastError;

  QueueState copyWith({
    bool? isUploading,
    String? currentFile,
    String? statusLabel,
    double? progressPercentage,
    int? completedFiles,
    int? totalFiles,
    bool? isPaused,
    String? lastError,
  }) {
    return QueueState(
      isUploading: isUploading ?? this.isUploading,
      currentFile: currentFile ?? this.currentFile,
      statusLabel: statusLabel ?? this.statusLabel,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      completedFiles: completedFiles ?? this.completedFiles,
      totalFiles: totalFiles ?? this.totalFiles,
      isPaused: isPaused ?? this.isPaused,
      lastError: lastError,
    );
  }
}

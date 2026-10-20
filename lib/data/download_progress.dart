/// Progress of a download, for a bar and a "x / y MB" line.
class DownloadProgress {
  final int done;
  final int total;

  /// What is being fetched right now (a file name), when known.
  final String? item;
  const DownloadProgress(this.done, this.total, [this.item]);
  double get fraction => total == 0 ? 1 : (done / total).clamp(0, 1);
}

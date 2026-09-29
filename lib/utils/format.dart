String fmtDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}/$m/$day';
}

String fmtRelative(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inHours < 1) return '${diff.inMinutes} 分鐘前';
  if (diff.inDays < 1) return '${diff.inHours} 小時前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  return fmtDate(d);
}

/// 把例外訊息整理成可以直接顯示給使用者的一行文字。
String friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Failed to fetch') ||
      s.contains('ClientException')) {
    return '連不上伺服器，請確認網路後再試';
  }
  if (s.contains('Invalid login credentials')) return '帳號或密碼錯誤';
  if (s.contains('User already registered')) return '這個 Email 已經註冊過了';
  if (s.contains('Password should be at least')) return '密碼至少要 6 個字';
  if (s.contains('Email not confirmed')) return '請先到信箱點擊確認連結';
  return s.replaceFirst('Exception: ', '');
}

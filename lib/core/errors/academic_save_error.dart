String academicSaveError(Object error) {
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message;
  return 'Could not save this change. Please try again.';
}

import 'package:equatable/equatable.dart';

abstract class Result<T> extends Equatable {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;
  String? get errorOrNull => isFailure ? (this as Failure<T>).error : null;

  @override
  List<Object?> get props => <Object?>[];
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  List<Object?> get props => <Object?>[data];
}

class Failure<T> extends Result<T> {
  final String error;
  final Exception? exception;
  const Failure(this.error, [this.exception]);

  @override
  List<Object?> get props => <Object?>[error, exception];
}

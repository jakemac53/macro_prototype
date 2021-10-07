class RunMacroRequest {
  final String identifier;
  final Map<String, Object?> arguments;

  RunMacroRequest(this.identifier, this.arguments);

  RunMacroRequest.fromJson(Map<String, Object?> json)
      : arguments = json['arguments'] as Map<String, Object?>,
        identifier = json['identifier'] as String;

  Map<String, Object?> toJson() => {
        'arguments': arguments,
        'identifier': identifier,
      };
}

class RunMacroResponse {
  final String generatedCode;

  RunMacroResponse(this.generatedCode);

  RunMacroResponse.fromJson(Map<String, Object?> json)
      : generatedCode = json['generatedCode'] as String;

  Map<String, Object?> toJson() => {'generatedCode': generatedCode};
}

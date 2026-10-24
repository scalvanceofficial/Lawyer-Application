import 'package:flutter/foundation.dart';

import '../models/legal_case.dart';
import '../repositories/case_repository.dart';
import '../repositories/consultation_repository.dart';
import '../services/case_payment_service.dart';
import '../services/app_error_message.dart';

class PendingCaseDocument {
  const PendingCaseDocument({
    required this.name,
    required this.bytes,
    this.contentType,
  });
  final String name;
  final Uint8List bytes;
  final String? contentType;
  int get size => bytes.length;
}

class CaseBookingController extends ChangeNotifier {
  CaseBookingController({
    CaseRepository? caseRepository,
    ConsultationRepository? consultationRepository,
    CasePaymentService? paymentService,
  }) : _caseRepository = caseRepository ?? CaseRepository(),
       _consultationRepository =
           consultationRepository ?? ConsultationRepository(),
       _paymentService = paymentService ?? CasePaymentService();

  final CaseRepository _caseRepository;
  final ConsultationRepository _consultationRepository;
  final CasePaymentService _paymentService;

  bool busy = false;
  String? error;
  List<LegalCase> availableCases = const [];

  Future<void> loadAvailableCases() async {
    await _run(() async {
      availableCases = await _caseRepository.openCases();
    });
  }

  Future<LegalCase> createCase({
    required String title,
    required String category,
    required String description,
    required List<PendingCaseDocument> documents,
  }) async {
    late LegalCase result;
    await _run(() async {
      final id = await _caseRepository.createCase(
        title: title,
        category: category,
        description: description,
      );
      for (final document in documents) {
        await _caseRepository.uploadDocument(
          caseId: id,
          name: document.name,
          bytes: document.bytes,
          contentType: document.contentType,
        );
      }
      result = await _caseRepository.getCase(id);
    });
    return result;
  }

  Future<LegalCase> activate({
    required LegalCase legalCase,
    required String clientName,
    required String email,
    required String phone,
  }) async {
    late LegalCase activated;
    await _run(() async {
      await _paymentService.activateCase(
        legalCase: legalCase,
        clientName: clientName,
        email: email,
        phone: phone,
      );
      activated = await _caseRepository.getCase(legalCase.id);
    });
    return activated;
  }

  Future<void> requestLawyer({
    required LegalCase legalCase,
    required String lawyerId,
    required String lawyerName,
    required String clientName,
    required String clientPhone,
    required String lawyerPhone,
  }) {
    return _run(
      () => _consultationRepository.requestLawyer(
        legalCase: legalCase,
        lawyerId: lawyerId,
        lawyerName: lawyerName,
        clientName: clientName,
        clientPhone: clientPhone,
        lawyerPhone: lawyerPhone,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      error = appErrorMessage(exception);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

import '../models/current_info_model.dart';
import '../models/question_model.dart';
import '../models/user_model.dart';
import '../models/wrong_question_model.dart';

/// Yerel / uzak veritabanı servisi iskeleti.
/// Production'da sqflite, hive veya Firebase ile genişletilebilir.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  void setCurrentUser(UserModel user) {
    _currentUser = user;
  }

  Future<List<QuestionModel>> getQuestionsByAltKonu(String altKonuAdi) async {
    // TODO: Gerçek veritabanı sorgusu
    return _mockQuestions.where((q) => q.altKonuAdi == altKonuAdi).toList();
  }

  Future<List<QuestionModel>> getAllQuestions() async {
    return List.unmodifiable(_mockQuestions);
  }

  Future<List<CurrentInfoModel>> getCurrentInfos() async {
    return List.unmodifiable(_mockCurrentInfos);
  }

  Future<List<WrongQuestionModel>> getWrongQuestions() async {
    return [];
  }

  Future<void> saveWrongQuestion(WrongQuestionModel model) async {
    // TODO: Kalıcı depolama
  }

  static final List<QuestionModel> _mockQuestions = [
    QuestionModel(
      id: 'q1',
      dersAdi: 'Türkçe',
      konuAdi: 'Anlam Bilgisi',
      altKonuAdi: 'Sözcükte Anlam',
      soruMetni: 'Aşağıdaki cümlelerin hangisinde "yürek" sözcüğü mecaz anlamda kullanılmıştır?',
      siklar: const {
        'A': 'Yüreği hızla atmaya başladı.',
        'B': 'Yüreği çok temiz bir insandı.',
        'C': 'Yüreğinde ağır bir yük taşıyordu.',
        'D': 'Yüreği sol tarafta bulunur.',
        'E': 'Yüreği ameliyat edildi.',
      },
      dogruCevap: 'B',
      cozumMetni: '"Yürek" sözcüğü B seçeneğinde "temiz kalpli, iyi niyetli" anlamında mecaz olarak kullanılmıştır.',
      guncellenmeTarihi: DateTime.now(),
    ),
    QuestionModel(
      id: 'q2',
      dersAdi: 'Türkçe',
      konuAdi: 'Anlam Bilgisi',
      altKonuAdi: 'Sözcükte Anlam',
      soruMetni: 'Hangisinde "el" sözcüğü gerçek anlamda kullanılmıştır?',
      siklar: const {
        'A': 'İşin elinde kaldı.',
        'B': 'Elini cebine attı.',
        'C': 'Elini taşın altına koydu.',
        'D': 'Eline düşen işi yaptı.',
        'E': 'Elini verdi, dost oldu.',
      },
      dogruCevap: 'B',
      cozumMetni: 'B seçeneğinde "el" vücut organı olarak gerçek anlamda kullanılmıştır.',
      guncellenmeTarihi: DateTime.now(),
    ),
  ];

  static final List<CurrentInfoModel> _mockCurrentInfos = [
    CurrentInfoModel(
      id: 'ci1',
      baslik: 'Tekrar Listem',
      aciklama: 'Anayasa maddeleri, idare hukuku kavramları ve tarih kronolojisi — tekrar edilecek konular.',
      imageUrl: null,
      eklenmeTarihi: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    CurrentInfoModel(
      id: 'ci2',
      baslik: 'Bugün Çalışacaklarım',
      aciklama: 'Türkçe: Cümle bilgisi · Matematik: Oran-orantı · Hedef: 3 deneme sınavı.',
      imageUrl: null,
      eklenmeTarihi: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

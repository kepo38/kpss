from django.core.management.base import BaseCommand

from content.models import Question, Subject, Topic, TopicTest
from content.topic_slots import ensure_all_topic_slots

# Flutter `lib/data/kpss_curriculum.dart` ile aynı çekirdek.
CURRICULUM = [
    {
        "slug": "turkce",
        "name": "Türkçe",
        "topics": [
            {"slug": "turkce_anlam", "name": "Sözcükte Anlam", "subtopics": []},
            {
                "slug": "turkce_cumlede_anlam",
                "name": "Cümlede Anlam",
                "subtopics": [],
            },
            {"slug": "turkce_paragraf", "name": "Paragraf", "subtopics": []},
            {
                "slug": "turkce_dilbilgisi",
                "name": "Dil Bilgisi",
                "subtopics": [],
            },
            {"slug": "turkce_ses", "name": "Ses Bilgisi", "subtopics": []},
            {
                "slug": "turkce_anlatim",
                "name": "Anlatım Bozuklukları",
                "subtopics": [],
            },
            {
                "slug": "turkce_yazim",
                "name": "Yazım Yanlışları",
                "subtopics": [],
            },
            {
                "slug": "turkce_noktalama",
                "name": "Noktalama İşaretleri",
                "subtopics": [],
            },
            {
                "slug": "turkce_sozel_mantik",
                "name": "Sözel Mantık Soruları",
                "subtopics": [],
            },
        ],
    },
    {
        "slug": "matematik",
        "name": "Matematik",
        "topics": [
            {"slug": "mat_temel", "name": "Temel Kavramlar", "subtopics": []},
            {
                "slug": "mat_rasyonel",
                "name": "Rasyonel Sayılar",
                "subtopics": [],
            },
            {"slug": "mat_koklu", "name": "Köklü Sayılar", "subtopics": []},
            {"slug": "mat_uslu", "name": "Üslü Sayılar", "subtopics": []},
            {
                "slug": "mat_problem",
                "name": "Problemler",
                "subtopics": [],
                "questions_per_test": 8,
            },
            {
                "slug": "mat_tablo_grafik",
                "name": "Tablo, Grafik Okuma ve Yorumlama",
                "subtopics": [],
            },
            {
                "slug": "mat_sayisal_mantik",
                "name": "Sayısal Mantık Soruları",
                "subtopics": [],
            },
            {
                "slug": "mat_geometri",
                "name": "Temel Geometri",
                "subtopics": [],
            },
        ],
    },
    {
        "slug": "tarih",
        "name": "Tarih",
        "topics": [
            {
                "slug": "tarih_islamiyet_oncesi",
                "name": "İslamiyet Öncesi Türk Tarihi",
                "subtopics": [],
            },
            {
                "slug": "tarih_turk_islam",
                "name": "İlk Türk - İslam Devletleri ve Beylikleri",
                "subtopics": [],
            },
            {
                "slug": "tarih_osmanli_kurulus_yukselme",
                "name": "Osmanlı Devleti Kuruluş ve Yükselme Dönemleri",
                "subtopics": [],
            },
            {
                "slug": "tarih_osmanli_kultur",
                "name": "Osmanlı Devleti’nde Kültür ve Uygarlık",
                "subtopics": [],
            },
            {
                "slug": "tarih_osmanli_17",
                "name": "XVII. Yüzyılda Osmanlı Devleti (Duraklama Dönemi)",
                "subtopics": [],
            },
            {
                "slug": "tarih_osmanli_18",
                "name": "XVIII. Yüzyılda Osmanlı Devleti (Gerileme Dönemi)",
                "subtopics": [],
            },
            {
                "slug": "tarih_osmanli_19",
                "name": "XIX. Yüzyılda Osmanlı Devleti (Dağılma Dönemi)",
                "subtopics": [],
            },
            {
                "slug": "tarih_osmanli_20",
                "name": "XX. Yüzyılda Osmanlı Devleti",
                "subtopics": [],
            },
            {
                "slug": "tarih_kurtulus_hazirlik",
                "name": "Kurtuluş Savaşı Hazırlık Dönemi",
                "subtopics": [],
            },
            {
                "slug": "tarih_tbmm",
                "name": "I. TBMM Dönemi",
                "subtopics": [],
            },
            {
                "slug": "tarih_kurtulus_muharebe",
                "name": "Kurtuluş Savaşı Muharebeler Dönemi",
                "subtopics": [],
            },
            {
                "slug": "tarih_inkilaplar",
                "name": "Atatürk İnkılapları",
                "subtopics": [],
            },
            {
                "slug": "tarih_ilkeler",
                "name": "Atatürk İlkeleri",
                "subtopics": [],
            },
            {
                "slug": "tarih_partiler",
                "name": "Partiler ve Partileşme Dönemi (İç Politika)",
                "subtopics": [],
            },
            {
                "slug": "tarih_dis_politika",
                "name": "Atatürk Dönemi Türk Dış Politikası",
                "subtopics": [],
            },
            {
                "slug": "tarih_sonrasi",
                "name": "Atatürk Sonrası Dönem",
                "subtopics": [],
            },
            {
                "slug": "tarih_ataturk_hayat",
                "name": "Atatürk’ün Hayatı ve Kişiliği",
                "subtopics": [],
            },
            {
                "slug": "tarih_cagdas_turk_dunya",
                "name": "Çağdaş Türk ve Dünya Tarihi",
                "subtopics": [
                    "II. Dünya Savaşı Dönemi (1939 - 1945)",
                    "Soğuk Savaş Dönemi (1945 - 1960'ların Başı)",
                    "Yumuşama (Detant) Dönemi ve Sonrası (1960'lar - 1980'ler)",
                    "Küreselleşen Dünya (1990'lardan Günümüze)",
                ],
            },
            {
                "slug": "tarih_kronoloji",
                "name": "Tarih Kronoloji",
                "subtopics": [],
            },
            {
                "slug": "tarih_padisah_antlasma",
                "name": "Padişahlar ve Antlaşmalar",
                "subtopics": [],
            },
        ],
    },
    {
        "slug": "cografya",
        "name": "Coğrafya",
        "topics": [
            {
                "slug": "cog_konum",
                "name": "Türkiye’nin Coğrafi Konumu",
                "subtopics": [
                    "Matematik (Mutlak) Konum",
                    "Türkiye’nin Matematik (Mutlak) Konumu ve Sonuçları",
                    "Türkiye’nin Özel (Göreceli) Konumu ve Sonuçları",
                    "Türkiye’nin Jeopolitiği",
                ],
            },
            {
                "slug": "cog_yersekilleri",
                "name": "Türkiye’nin Yerşekilleri ve Özellikleri",
                "subtopics": [
                    "Türkiye’nin Yerşekillerinin Genel Özellikleri",
                    "Fiziki Haritalar",
                    "Türkiye’nin Jeolojik Geçmişi",
                    "Türkiye’nin Platoları ve Ovaları",
                    "Türkiye’de Dış Güçlerin Oluşturduğu Yer Şekilleri",
                    "Türkiye’nin Kıyı Tipleri",
                    "Türkiye’de Toprak Oluşumu ve Tipleri",
                    "Türkiye’nin Su Varlığı",
                    "Türkiye’de Doğal Afetler",
                ],
            },
            {
                "slug": "cog_iklim_bitki",
                "name": "Türkiye’nin İklimi ve Bitki Örtüsü",
                "subtopics": [
                    "Türkiye’nin İklimi",
                    "Türkiye’de Sıcaklık",
                    "Türkiye’de Nemlilik ve Yağış",
                    "Türkiye’de İklim Tipleri",
                    "Türkiye’nin Bitki Örtüsü",
                    "Türkiye’nin İklim Tipleri ve Bitki Örtüsü",
                ],
            },
            {
                "slug": "cog_nufus_yerlesme",
                "name": "Türkiye’de Nüfus ve Yerleşme",
                "subtopics": [
                    "Türkiye’de Nüfus Özellikleri",
                    "Türkiye’de Nüfusun Dağılışı ve Nüfus Yoğunluğu",
                    "Türkiye’nin Nüfusu ve Nüfus Sayımları",
                    "Türkiye’nin Nüfus Politikaları",
                    "Türkiye’de Nüfus Projeksiyonları",
                    "Türkiye’de Göçler",
                    "Türkiye’de Yerleşme",
                    "Türkiye’de Mesken Tipleri",
                ],
            },
            {
                "slug": "cog_anadolu_uygarlik",
                "name": "Anadolu Uygarlıkları",
                "subtopics": [],
            },
            {
                "slug": "cog_tarim",
                "name": "Türkiye’de Tarım, Hayvancılık ve Ormancılık",
                "subtopics": [
                    "Türkiye’de Arazi Kullanımı",
                    "Türkiye Ekonomisinin Sektörel Dağılımı",
                    "Türkiye Ekonomisini Etkileyen Faktörler",
                    "Türkiye’de Tarım",
                    "Türkiye’de Hayvancılık",
                    "Türkiye’de Ormancılık",
                ],
            },
            {
                "slug": "cog_maden_enerji_sanayi",
                "name": "Türkiye’de Madenler, Enerji Kaynakları ve Sanayi",
                "subtopics": [
                    "Türkiye’de Madenler",
                    "Türkiye’de Enerji Kaynakları",
                    "Türkiye’de Sanayi",
                ],
            },
            {
                "slug": "cog_ulasim_ticaret_turizm",
                "name": "Türkiye’de Ulaşım, Ticaret ve Turizm",
                "subtopics": [
                    "Türkiye’de Ulaşım",
                    "Türkiye’de Ticaret",
                    "Türkiye’de Turizm",
                    "Türkiye’nin Millî Parkları",
                    "Türkiye’de Şehirler ve Özellikleri",
                ],
            },
            {
                "slug": "cog_bolgeler",
                "name": "Türkiye’nin Coğrafi Bölgeleri",
                "subtopics": [
                    "Türkiye’de Bölge Sınıflandırması",
                    "Türkiye’nin Bölgesel Kalkınma Projeleri",
                    "Karadeniz Bölgesi",
                    "Marmara Bölgesi",
                    "Ege Bölgesi",
                    "Akdeniz Bölgesi",
                    "İç Anadolu Bölgesi",
                    "Doğu Anadolu Bölgesi",
                    "Güneydoğu Anadolu Bölgesi",
                    "Bölgelerin Özelliklerinin Karşılaştırılması",
                ],
            },
        ],
    },
    {
        "slug": "vatandaslik",
        "name": "Vatandaşlık",
        "topics": [
            {
                "slug": "vat_hukuk_temel",
                "name": "Hukukun Temel Kavramları",
                "subtopics": [],
            },
            {
                "slug": "vat_devlet_demokrasi",
                "name": "Devlet Biçimleri, Demokrasi ve Kuvvetler Ayrılığı",
                "subtopics": [],
            },
            {
                "slug": "vat_anayasa_giris",
                "name": "Anayasa Hukukuna Giriş, Temel Kavramlar ve Türk Anayasa Tarihi",
                "subtopics": [],
            },
            {
                "slug": "vat_1982_ilkeler",
                "name": "1982 Anayasasının Temel İlkeleri",
                "subtopics": [],
            },
            {
                "slug": "vat_yasama",
                "name": "Yasama",
                "subtopics": [],
            },
            {
                "slug": "vat_yurutme",
                "name": "Yürütme",
                "subtopics": [],
            },
            {
                "slug": "vat_yargi",
                "name": "Yargı",
                "subtopics": [],
            },
            {
                "slug": "vat_temel_haklar",
                "name": "Temel Hak ve Hürriyetler",
                "subtopics": [],
            },
            {
                "slug": "vat_idare_hukuku",
                "name": "İdare Hukuku",
                "subtopics": [],
            },
        ],
    },
    {
        "slug": "guncel",
        "name": "Güncel Bilgiler",
        "topics": [
            {
                "slug": "guncel_tr",
                "name": "Türkiye Gündemi",
                "subtopics": ["Siyaset", "Ekonomi", "Toplum"],
            },
            {
                "slug": "guncel_dunya",
                "name": "Dünya Gündemi",
                "subtopics": [
                    "Uluslararası Örgütler",
                    "Jeopolitik",
                    "Bilim-Teknoloji",
                ],
            },
        ],
    },
]


class Command(BaseCommand):
    help = "Müfredatı seed eder; örnek yayınlanmış soru/test ekler."

    def handle(self, *args, **options):
        keep_subject_slugs = {s["slug"] for s in CURRICULUM}
        for i, subject_data in enumerate(CURRICULUM):
            subject, _ = Subject.objects.update_or_create(
                slug=subject_data["slug"],
                defaults={
                    "name": subject_data["name"],
                    "sort_order": i,
                    "is_active": True,
                },
            )
            for j, topic_data in enumerate(subject_data["topics"]):
                Topic.objects.update_or_create(
                    subject=subject,
                    slug=topic_data["slug"],
                    defaults={
                        "name": topic_data["name"],
                        "subtopics": topic_data.get("subtopics", []),
                        "sort_order": j,
                        "is_active": True,
                        "questions_per_test": topic_data.get(
                            "questions_per_test", 20
                        ),
                    },
                )
            # Müfredatta olmayan eski konuları pasifleştir
            keep_slugs = {t["slug"] for t in subject_data["topics"]}
            subject.topics.exclude(slug__in=keep_slugs).update(is_active=False)

        # Müfredat dışı dersleri (ör. yanlışlıkla eklenen "Sync") pasifleştir
        deactivated = Subject.objects.exclude(
            slug__in=keep_subject_slugs
        ).update(is_active=False)
        if deactivated:
            self.stdout.write(
                self.style.WARNING(
                    f"{deactivated} müfredat dışı ders pasifleştirildi."
                )
            )

        topic = Topic.objects.get(slug="turkce_anlam")
        samples = [
            {
                "public_id": "q_tr_1",
                "subtopic": "Sözcükte Anlam",
                "stem": (
                    '"Kalemi güçlü bir yazardır." cümlesinde altı çizili sözün '
                    "anlamı aşağıdakilerden hangisidir?"
                ),
                "option_a": "Yazı yazma aracı sağlamdır",
                "option_b": "Anlatımı etkilidir",
                "option_c": "Fiziksel gücü fazladır",
                "option_d": "Çok kitap okur",
                "option_e": "Hızlı yazar",
                "correct_option": "B",
                "solution": (
                    '"Kalemi güçlü" mecazı, yazarın anlatımının etkili '
                    "olduğunu belirtir."
                ),
            },
            {
                "public_id": "q_tr_2",
                "subtopic": "Cümlede Anlam",
                "stem": (
                    'Aşağıdaki cümlelerin hangisinde "karşıtlık" ilişkisi vardır?'
                ),
                "option_a": "Hava güneşliydi ve herkes dışarıdaydı.",
                "option_b": "Çalıştı; ancak istediği sonucu alamadı.",
                "option_c": "Kitabı bitirdi, sonra uyudu.",
                "option_d": "Yağmur yağdığı için evde kaldık.",
                "option_e": "Hem çay hem kahve içti.",
                "correct_option": "B",
                "solution": '"Ancak" bağlacı karşıtlık bildirir.',
            },
        ]
        created_qs = []
        for data in samples:
            q, _ = Question.objects.update_or_create(
                public_id=data["public_id"],
                defaults={
                    "topic": topic,
                    "subtopic": data["subtopic"],
                    "stem": data["stem"],
                    "option_a": data["option_a"],
                    "option_b": data["option_b"],
                    "option_c": data["option_c"],
                    "option_d": data["option_d"],
                    "option_e": data["option_e"],
                    "correct_option": data["correct_option"],
                    "solution": data["solution"],
                    "is_published": True,
                },
            )
            created_qs.append(q)

        mat_topic = Topic.objects.get(slug="mat_temel")
        q_mat, _ = Question.objects.update_or_create(
            public_id="q_mat_1",
            defaults={
                "topic": mat_topic,
                "subtopic": "Sayılar",
                "stem": "3² + 4² işleminin sonucu kaçtır?",
                "option_a": "7",
                "option_b": "12",
                "option_c": "25",
                "option_d": "49",
                "option_e": "5",
                "correct_option": "C",
                "solution": "9 + 16 = 25",
                "is_published": True,
            },
        )

        test, _ = TopicTest.objects.update_or_create(
            public_id="test_seed_tr_anlam",
            defaults={
                "topic": topic,
                "title": "Anlam Bilgisi · Tanışma Testi",
                "description": "Konuya ısınma — 2 soruluk örnek paket",
                "time_limit_minutes": 0,
                "is_published": True,
            },
        )
        test.questions.set(created_qs)

        slot_stats = ensure_all_topic_slots(migrate_legacy_tests=True)
        self.stdout.write(
            self.style.SUCCESS(
                f"Müfredat hazır. Sorular: {Question.objects.count()}, "
                f"testler: {TopicTest.objects.count()} "
                f"(mat örnek: {q_mat.public_id}) · "
                f"{slot_stats['topics']} konuda 5+5 yuva"
            )
        )

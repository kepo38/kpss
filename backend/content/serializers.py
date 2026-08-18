from rest_framework import serializers

from .models import Announcement, DeviceToken, Question, Subject, Topic, TopicLesson, TopicTest, UserMessage
from .models import ExamPack, ExamPackExam
from .test_grouping import order_questions_keeping_scenarios


class TopicSerializer(serializers.ModelSerializer):
    class Meta:
        model = Topic
        fields = (
            "slug",
            "name",
            "subtopics",
            "questions_per_test",
            "time_limit_minutes",
            "shuffle_questions",
            "shuffle_options",
            "show_solution_after_each",
        )


class SubjectSerializer(serializers.ModelSerializer):
    topics = serializers.SerializerMethodField()

    class Meta:
        model = Subject
        fields = ("slug", "name", "topics")

    def get_topics(self, obj: Subject) -> list:
        qs = obj.topics.filter(is_active=True).order_by("sort_order", "name")
        return TopicSerializer(qs, many=True).data


class QuestionSerializer(serializers.ModelSerializer):
    id = serializers.CharField(source="public_id")
    dersAdi = serializers.CharField(source="topic.subject.name")
    konuAdi = serializers.CharField(source="topic.name")
    altKonuAdi = serializers.CharField(source="subtopic")
    soruMetni = serializers.CharField(source="stem")
    imageUrl = serializers.SerializerMethodField()
    sekilKodu = serializers.CharField(source="figure_svg", allow_blank=True)
    siklar = serializers.SerializerMethodField()
    dogruCevap = serializers.CharField(source="correct_option")
    cozumMetni = serializers.CharField(source="solution")
    guncellenmeTarihi = serializers.DateTimeField(source="updated_at")
    osymSordu = serializers.BooleanField(source="osym_sordu")
    difficulty = serializers.CharField()
    attemptCount = serializers.IntegerField(source="attempt_count")
    correctRate = serializers.SerializerMethodField()
    difficultyVisible = serializers.BooleanField(source="difficulty_visible")
    qualityScore = serializers.SerializerMethodField()
    ratingCount = serializers.SerializerMethodField()
    scenarioId = serializers.SerializerMethodField()
    scenarioTitle = serializers.SerializerMethodField()
    scenarioStem = serializers.SerializerMethodField()
    scenarioOrder = serializers.IntegerField(source="scenario_order")

    class Meta:
        model = Question
        fields = (
            "id",
            "dersAdi",
            "konuAdi",
            "altKonuAdi",
            "soruMetni",
            "imageUrl",
            "sekilKodu",
            "siklar",
            "dogruCevap",
            "cozumMetni",
            "guncellenmeTarihi",
            "osymSordu",
            "difficulty",
            "attemptCount",
            "correctRate",
            "difficultyVisible",
            "qualityScore",
            "ratingCount",
            "scenarioId",
            "scenarioTitle",
            "scenarioStem",
            "scenarioOrder",
        )

    def get_siklar(self, obj: Question) -> dict:
        return obj.options_map()

    def get_imageUrl(self, obj: Question) -> str | None:
        request = self.context.get("request")
        if not obj.image:
            return None
        url = obj.image.url
        if request is not None:
            url = request.build_absolute_uri(url)
        ts = int(obj.updated_at.timestamp()) if obj.updated_at else 0
        sep = "&" if "?" in url else "?"
        return f"{url}{sep}v={ts}"

    def get_correctRate(self, obj: Question) -> float | None:
        rate = obj.correct_rate
        return round(rate, 4) if rate is not None else None

    def get_qualityScore(self, obj: Question) -> float | None:
        from django.db.models import Avg

        value = obj.ratings.aggregate(value=Avg("stars"))["value"]
        return round(float(value), 2) if value is not None else None

    def get_ratingCount(self, obj: Question) -> int:
        return obj.ratings.count()

    def _published_scenario(self, obj: Question):
        scenario = getattr(obj, "scenario", None)
        if scenario is None or not scenario.is_published:
            return None
        return scenario

    def get_scenarioId(self, obj: Question) -> str | None:
        scenario = self._published_scenario(obj)
        return str(scenario.id) if scenario is not None else None

    def get_scenarioTitle(self, obj: Question) -> str | None:
        scenario = self._published_scenario(obj)
        return scenario.title if scenario is not None else None

    def get_scenarioStem(self, obj: Question) -> str | None:
        scenario = self._published_scenario(obj)
        return scenario.stem if scenario is not None else None


class TopicTestSerializer(serializers.ModelSerializer):
    id = serializers.CharField(source="public_id")
    topicId = serializers.CharField(source="topic.slug")
    questionCount = serializers.SerializerMethodField()
    timeLimitMinutes = serializers.IntegerField(source="time_limit_minutes")
    questionIds = serializers.SerializerMethodField()
    createdAt = serializers.DateTimeField(source="created_at")
    published = serializers.BooleanField(source="is_published")

    class Meta:
        model = TopicTest
        fields = (
            "id",
            "topicId",
            "title",
            "description",
            "questionCount",
            "timeLimitMinutes",
            "questionIds",
            "createdAt",
            "published",
        )

    def _published_questions(self, obj: TopicTest):
        # Prefetch cache kullan (filter() yeni sorgu açar)
        published = [
            q
            for q in obj.questions.all()
            if q.is_published and q.topic_id == obj.topic_id
        ]
        return order_questions_keeping_scenarios(published)

    def get_questionIds(self, obj: TopicTest) -> list[str]:
        return [q.public_id for q in self._published_questions(obj)]

    def get_questionCount(self, obj: TopicTest) -> int:
        return len(self._published_questions(obj))


class TopicLessonSerializer(serializers.ModelSerializer):
    id = serializers.CharField(source="public_id")
    topicId = serializers.CharField(source="topic.slug")
    imageUrl = serializers.SerializerMethodField()
    sortOrder = serializers.IntegerField(source="sort_order")

    class Meta:
        model = TopicLesson
        fields = (
            "id",
            "topicId",
            "title",
            "body",
            "imageUrl",
            "sortOrder",
        )

    def get_imageUrl(self, obj: TopicLesson) -> str | None:
        request = self.context.get("request")
        if not obj.image:
            return None
        url = obj.image.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url


class ContentPackSerializer(serializers.Serializer):
    """Mobil uygulamanın indirdiği yayın paketi."""

    version = serializers.IntegerField()
    generatedAt = serializers.DateTimeField()
    subjects = SubjectSerializer(many=True)
    questions = QuestionSerializer(many=True)
    tests = TopicTestSerializer(many=True)
    lessons = TopicLessonSerializer(many=True)


class ContentCatalogSerializer(serializers.Serializer):
    """Hafif katalog — soru gövdeleri yok; test başında ayrı çekilir."""

    version = serializers.IntegerField()
    generatedAt = serializers.DateTimeField()
    subjects = SubjectSerializer(many=True)
    tests = TopicTestSerializer(many=True)
    lessons = TopicLessonSerializer(many=True)


class AnnouncementSerializer(serializers.ModelSerializer):
    imageUrl = serializers.SerializerMethodField()

    class Meta:
        model = Announcement
        fields = (
            "id",
            "title",
            "body",
            "imageUrl",
            "created_at",
            "push_sent_at",
        )

    def get_imageUrl(self, obj: Announcement) -> str | None:
        request = self.context.get("request")
        if not obj.image:
            return None
        url = obj.image.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url


class UserMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserMessage
        fields = ("id", "title", "body", "is_read", "created_at")


class DeviceTokenSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=512)
    platform = serializers.ChoiceField(
        choices=["android", "ios", "other"], default="android", required=False
    )
    app_version = serializers.CharField(
        max_length=32, required=False, allow_blank=True, default=""
    )

    def create(self, validated_data):
        token = validated_data["token"].strip()
        platform = validated_data.get("platform") or "android"
        app_version = validated_data.get("app_version") or ""
        user = self.context.get("user")
        defaults = {
            "platform": platform,
            "app_version": app_version,
            "is_active": True,
        }
        if user is not None:
            defaults["user"] = user
        obj, _ = DeviceToken.objects.update_or_create(
            token=token,
            defaults=defaults,
        )
        return obj


class ExamPackExamSummarySerializer(serializers.ModelSerializer):
    index = serializers.IntegerField()
    title = serializers.CharField()
    questionCount = serializers.SerializerMethodField()

    class Meta:
        model = ExamPackExam
        fields = ("index", "title", "questionCount")

    def get_questionCount(self, obj: ExamPackExam) -> int:
        return obj.question_count


class ExamPackSerializer(serializers.ModelSerializer):
    id = serializers.CharField(source="public_id")
    examTypeId = serializers.CharField(source="exam_type.slug")
    packKind = serializers.CharField(source="pack_kind")
    subjectId = serializers.SerializerMethodField()
    subjectName = serializers.SerializerMethodField()
    examCount = serializers.IntegerField(source="exam_count")
    timeLimitMinutes = serializers.IntegerField(source="time_limit_minutes")
    priceDisplay = serializers.CharField(source="price_display")
    playProductId = serializers.CharField(source="play_product_id")
    published = serializers.BooleanField(source="is_published")
    sortOrder = serializers.IntegerField(source="sort_order")
    questionsPerExam = serializers.SerializerMethodField()
    exams = serializers.SerializerMethodField()

    class Meta:
        model = ExamPack
        fields = (
            "id",
            "examTypeId",
            "packKind",
            "subjectId",
            "subjectName",
            "title",
            "description",
            "examCount",
            "timeLimitMinutes",
            "priceDisplay",
            "playProductId",
            "published",
            "sortOrder",
            "questionsPerExam",
            "exams",
        )

    def get_subjectId(self, obj: ExamPack) -> str | None:
        return obj.subject.slug if obj.subject_id else None

    def get_subjectName(self, obj: ExamPack) -> str | None:
        return obj.subject.name if obj.subject_id else None

    def get_questionsPerExam(self, obj: ExamPack) -> int:
        return obj.questions_per_exam

    def get_exams(self, obj: ExamPack) -> list:
        include_exams = self.context.get("include_exams", False)
        if not include_exams:
            return []
        qs = obj.exams.all().order_by("index")
        return ExamPackExamSummarySerializer(qs, many=True).data


class ExamPackListSerializer(ExamPackSerializer):
    class Meta(ExamPackSerializer.Meta):
        fields = tuple(
            f
            for f in ExamPackSerializer.Meta.fields
            if f != "exams"
        )

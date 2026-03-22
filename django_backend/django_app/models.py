import uuid
from django.db import models
from django.contrib.auth.models import User

# 1. KULLANICI PROFİLİ VE ABONELİK
class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    is_premium = models.BooleanField(default=False)
    photo_credits = models.IntegerField(default=5)  # Ücretsiz deneme kredisi
    target_score = models.IntegerField(null=True, blank=True)
    daily_study_hours = models.FloatField(default=4.0)

    def __str__(self):
        return self.user.username

# 2. SORU BANKASI VE TAKSONOMİ
class Category(models.Model):
    name = models.CharField(max_length=100)

    def __str__(self):
        return self.name

class Topic(models.Model):
    category = models.ForeignKey(Category, on_delete=models.CASCADE)
    name = models.CharField(max_length=200)  # Islahatlar, Yer Şekilleri vb.
    tags = models.JSONField(default=list)  # otomatik etiketler/konu etiketleri

    def __str__(self):
        return f"{self.category.name} - {self.name}"

class Question(models.Model):
    topic = models.ForeignKey(Topic, on_delete=models.SET_NULL, null=True, related_name='questions')
    question_text = models.TextField()
    image = models.ImageField(upload_to='questions/', null=True, blank=True)
    option_a = models.CharField(max_length=500)
    option_b = models.CharField(max_length=500)
    option_c = models.CharField(max_length=500)
    option_d = models.CharField(max_length=500)
    option_e = models.CharField(max_length=500)
    correct_answer = models.CharField(max_length=1, choices=[('A','A'),('B','B'),('C','C'),('D','D'),('E','E')])
    solution_text = models.TextField(null=True, blank=True)
    tags = models.JSONField(default=list)
    created_at = models.DateTimeField(auto_now_add=True)

class QuestionTag(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    question = models.ForeignKey(Question, on_delete=models.CASCADE, related_name='tags_rel')
    tag_name = models.CharField(max_length=50)

# 3. DİNAMİK PROGRAM VE GÖREVLER
class StudyProgram(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='study_programs')
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)

class Task(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Beklemede'),
        ('completed', 'Tamamlandı'),
        ('deferred', 'Ertelendi'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    topic = models.ForeignKey(Topic, on_delete=models.CASCADE)
    planned_date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    is_from_analysis = models.BooleanField(default=False) # Foto-analiz sonucu mu eklendi?

# 4. FOTO-ANALİZ KAYITLARI
class UserAnswer(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='answers')
    question = models.ForeignKey(Question, on_delete=models.CASCADE, related_name='answers')
    is_correct = models.BooleanField(null=True)
    time_spent = models.IntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class PhotoAnalysis(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    image = models.ImageField(upload_to='user_uploads/')
    ocr_text = models.TextField(null=True, blank=True)
    detected_topic = models.ForeignKey(Topic, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

class UploadLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True)
    row_number = models.IntegerField(null=True, blank=True)
    error_message = models.TextField()
    file_name = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
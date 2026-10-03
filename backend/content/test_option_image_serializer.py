from django.core.files.base import ContentFile
from django.test import RequestFactory, TestCase

from content.models import Question, Subject, Topic
from content.option_image_crop import VISUAL_OPTION_PLACEHOLDER
from content.serializers import QuestionSerializer


class OptionImageSerializerTests(TestCase):
    def setUp(self):
        subject = Subject.objects.create(slug="opt_img_subj", name="Opt", sort_order=1)
        self.topic = Topic.objects.create(
            subject=subject, slug="opt_img_topic", name="Opt Konu"
        )
        self.request = RequestFactory().get("/")

    def test_text_options_have_no_images(self):
        q = Question.objects.create(
            topic=self.topic,
            public_id="q_opt_text",
            stem="Metin şık",
            option_a="1",
            option_b="2",
            option_c="3",
            option_d="4",
            option_e="5",
            correct_option="A",
            is_published=True,
            options_are_images=False,
        )
        data = QuestionSerializer(q, context={"request": self.request}).data
        self.assertFalse(data["optionsAreImages"])
        self.assertEqual(data["siklar"]["A"], "1")
        for letter in "ABCDE":
            self.assertIsNone(data["optionImageUrls"][letter])

    def test_visual_options_expose_urls(self):
        q = Question.objects.create(
            topic=self.topic,
            public_id="q_opt_vis",
            stem="Görsel şık soru",
            option_a=VISUAL_OPTION_PLACEHOLDER,
            option_b=VISUAL_OPTION_PLACEHOLDER,
            option_c=VISUAL_OPTION_PLACEHOLDER,
            option_d=VISUAL_OPTION_PLACEHOLDER,
            option_e=VISUAL_OPTION_PLACEHOLDER,
            correct_option="C",
            is_published=True,
            options_are_images=True,
        )
        tiny = (
            b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
            b"\xff\xdb\x00C\x00" + bytes([8] * 64) + b"\xff\xd9"
        )
        for letter in "ABCDE":
            getattr(q, f"option_{letter.lower()}_image").save(
                f"opt_{letter}.jpg",
                ContentFile(tiny),
                save=False,
            )
        q.save()
        data = QuestionSerializer(q, context={"request": self.request}).data
        self.assertTrue(data["optionsAreImages"])
        self.assertIsNone(data["imageUrl"])
        for letter in "ABCDE":
            url = data["optionImageUrls"][letter]
            self.assertIsNotNone(url)
            self.assertIn("/media/", url)
            self.assertIn("v=", url)

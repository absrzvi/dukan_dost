import pytest
from django.test import TestCase
from django.utils import timezone
from unittest.mock import patch
from .models import OTPRequest


class TestOTPRequest(TestCase):
    def test_create_otp_request(self):
        otp = OTPRequest.create_for_phone(phone='+923001234567', otp_code='123456')
        self.assertIsNotNone(otp.id)
        self.assertFalse(otp.is_used)
        self.assertFalse(otp.is_expired)
        # Hash stored, not plaintext
        self.assertNotEqual(otp.otp_hash, '123456')
        self.assertEqual(len(otp.otp_hash), 64)  # SHA-256 hex

    def test_verify_correct_otp(self):
        otp = OTPRequest.create_for_phone(phone='+923001234567', otp_code='654321')
        result = otp.verify('654321')
        self.assertTrue(result)
        self.assertTrue(otp.is_used)

    def test_verify_wrong_otp(self):
        otp = OTPRequest.create_for_phone(phone='+923001234567', otp_code='111111')
        result = otp.verify('999999')
        self.assertFalse(result)
        self.assertFalse(otp.is_used)
        self.assertEqual(otp.attempt_count, 1)

    def test_verify_expired_otp(self):
        otp = OTPRequest.create_for_phone(phone='+923001234567', otp_code='222222')
        otp.expires_at = timezone.now() - timezone.timedelta(minutes=1)
        otp.save()
        result = otp.verify('222222')
        self.assertFalse(result)

    def test_verify_used_otp(self):
        otp = OTPRequest.create_for_phone(phone='+923001234567', otp_code='333333')
        otp.verify('333333')  # first verify — success
        result = otp.verify('333333')  # second verify — should fail
        self.assertFalse(result)

    def test_max_attempts_blocks_verify(self):
        otp = OTPRequest.create_for_phone(phone='+923001234567', otp_code='444444')
        otp.verify('000000')
        otp.verify('000000')
        otp.verify('000000')
        # 4th attempt should be blocked even with correct code
        result = otp.verify('444444')
        self.assertFalse(result)


class TestOTPRequestView(TestCase):
    def test_request_otp_valid_phone(self):
        with patch('apps.authentication.views.send_sms', return_value=True):
            response = self.client.post(
                '/api/auth/otp/request/',
                {'phone': '+923001234567'},
                content_type='application/json',
            )
        self.assertEqual(response.status_code, 200)
        self.assertIn('expires_in_seconds', response.json())

    def test_request_otp_invalid_phone(self):
        response = self.client.post(
            '/api/auth/otp/request/',
            {'phone': '03001234567'},  # missing +92
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 400)

    def test_rate_limit_enforced(self):
        with patch('apps.authentication.views.send_sms', return_value=True):
            for _ in range(5):
                self.client.post(
                    '/api/auth/otp/request/',
                    {'phone': '+923009999999'},
                    content_type='application/json',
                )
            response = self.client.post(
                '/api/auth/otp/request/',
                {'phone': '+923009999999'},
                content_type='application/json',
            )
        self.assertEqual(response.status_code, 429)

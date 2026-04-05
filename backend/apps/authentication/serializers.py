from rest_framework import serializers
import re


class OTPRequestSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)

    def validate_phone(self, value: str) -> str:
        # E.164 format: +923001234567
        if not re.match(r'^\+92[0-9]{10}$', value):
            raise serializers.ValidationError(
                'Phone number must be in E.164 format for Pakistan: +92XXXXXXXXXX'
            )
        return value


class OTPVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    otp = serializers.CharField(min_length=6, max_length=6)

    def validate_phone(self, value: str) -> str:
        if not re.match(r'^\+92[0-9]{10}$', value):
            raise serializers.ValidationError('Invalid phone number format')
        return value

    def validate_otp(self, value: str) -> str:
        if not value.isdigit():
            raise serializers.ValidationError('OTP must be 6 digits')
        return value

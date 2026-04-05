import uuid
import hashlib
from django.db import models
from django.utils import timezone


class OTPRequest(models.Model):
    """
    Stores OTP requests. otp_hash is SHA-256 of the OTP code — never plaintext.
    Rate limited: max 5 requests per phone per hour.
    OTP expires after 5 minutes. Single-use only.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=20)  # E.164 format
    otp_hash = models.CharField(max_length=64)  # SHA-256 hex digest
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    attempts = models.IntegerField(default=0)  # failed verify attempts

    class Meta:
        indexes = [
            models.Index(fields=['phone', 'created_at']),
        ]

    @property
    def is_expired(self) -> bool:
        return timezone.now() > self.expires_at

    @staticmethod
    def hash_otp(otp_code: str) -> str:
        return hashlib.sha256(otp_code.encode()).hexdigest()

    @classmethod
    def create_for_phone(cls, phone: str, otp_code: str) -> 'OTPRequest':
        """Create a new OTP request. Expires in 5 minutes."""
        return cls.objects.create(
            phone=phone,
            otp_hash=cls.hash_otp(otp_code),
            expires_at=timezone.now() + timezone.timedelta(minutes=5),
        )

    def verify(self, otp_code: str) -> bool:
        """Verify OTP. Increments attempts. Marks as used on success."""
        if self.is_expired or self.is_used or self.attempts >= 3:
            return False
        self.attempts += 1
        if self.hash_otp(otp_code) == self.otp_hash:
            self.is_used = True
            self.save(update_fields=['attempts', 'is_used'])
            return True
        self.save(update_fields=['attempts'])
        return False


class ShopToken(models.Model):
    """Persistent session token for shop authentication. One token per shop (replaced on new login)."""
    key = models.CharField(max_length=64, primary_key=True)
    shop = models.OneToOneField('shops.Shop', on_delete=models.CASCADE, related_name='token')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'shop_tokens'

    @classmethod
    def create_for_shop(cls, shop: 'Shop') -> 'ShopToken':  # type: ignore[name-defined]
        import secrets as secrets_module
        key = secrets_module.token_hex(32)
        # Delete existing token if any
        cls.objects.filter(shop=shop).delete()
        return cls.objects.create(key=key, shop=shop)

    def __str__(self) -> str:
        return f"Token for {self.shop.phone} (created {self.created_at})"

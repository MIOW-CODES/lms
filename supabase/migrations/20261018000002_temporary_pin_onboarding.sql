-- Newly provisioned accounts start with temporary credentials, regardless of
-- role. Existing private credentials and explicit onboarding flags are kept.
-- Self-service PIN replacement clears the flag; administrative resets set it.
ALTER TABLE public.profiles ALTER COLUMN pin_must_change SET DEFAULT true;

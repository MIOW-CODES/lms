-- All existing worksheets require explicit teacher approval for another try.
-- Keep submitted work and individual teacher grants intact.
UPDATE quizzes SET allow_retake = false, max_attempts = 1
WHERE deleted_at IS NULL;

ALTER TABLE quizzes ALTER COLUMN allow_retake SET DEFAULT false;
ALTER TABLE quizzes ALTER COLUMN max_attempts SET DEFAULT 1;

"""The one error type. Handlers raise ApiError; the server renders it."""


class ApiError(Exception):
    def __init__(self, status, code, message):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message

    def body(self):
        return {"type": "error", "code": self.code, "message": self.message}

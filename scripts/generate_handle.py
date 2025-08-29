import uuid


def create_handle():
    return "h" + uuid.uuid4().hex

import unittest

from b24agent.client import Bitrix24Client, Bitrix24Error, MethodNotAvailableError


class FakeResponse:
    def __init__(self, payload, status_code=200):
        self._payload = payload
        self.status_code = status_code
        self.ok = status_code < 400
        self.reason = "OK" if self.ok else "Error"
        self.text = str(payload)

    def json(self):
        return self._payload


class FakeSession:
    """Отдаёт заранее подготовленные ответы по очереди."""

    def __init__(self, responses):
        self.responses = list(responses)
        self.requests = []

    def post(self, url, json=None, timeout=None):
        self.requests.append({"url": url, "json": json})
        return self.responses.pop(0)


def make_client(responses):
    client = Bitrix24Client("https://example.bitrix24.ru/rest/1/token", requests_per_second=0)
    client._session = FakeSession(responses)
    return client


class CallTest(unittest.TestCase):
    def test_ok(self):
        client = make_client([FakeResponse({"result": {"ID": "7"}})])
        self.assertEqual(client.call("profile"), {"ID": "7"})

    def test_method_not_found(self):
        client = make_client(
            [FakeResponse({"error": "ERROR_METHOD_NOT_FOUND", "error_description": "нет метода"}, 400)]
        )
        with self.assertRaises(MethodNotAvailableError):
            client.call("imopenlines.v2.Session.list")

    def test_generic_error(self):
        client = make_client(
            [FakeResponse({"error": "ACCESS_DENIED", "error_description": "нет прав"}, 403)]
        )
        with self.assertRaises(Bitrix24Error) as ctx:
            client.call("tasks.task.list")
        self.assertEqual(ctx.exception.code, "ACCESS_DENIED")

    def test_retry_on_query_limit(self):
        client = make_client(
            [
                FakeResponse({"error": "QUERY_LIMIT_EXCEEDED", "error_description": "лимит"}, 503),
                FakeResponse({"result": []}),
            ]
        )
        client.max_retries = 2
        self.assertEqual(client.call("tasks.task.list"), [])


class PaginationTest(unittest.TestCase):
    def test_iter_list_start_pagination(self):
        client = make_client(
            [
                FakeResponse({"result": {"tasks": [{"id": 1}, {"id": 2}]}, "next": 2, "total": 3}),
                FakeResponse({"result": {"tasks": [{"id": 3}]}, "total": 3}),
            ]
        )
        items = list(client.iter_list("tasks.task.list", {"filter": {}}, items_key="tasks"))
        self.assertEqual([i["id"] for i in items], [1, 2, 3])
        self.assertEqual(client._session.requests[1]["json"]["start"], 2)

    def test_iter_offset_list(self):
        client = make_client(
            [
                FakeResponse({"result": {"sessions": [{"id": 1}], "hasNextPage": True}}),
                FakeResponse({"result": {"sessions": [{"id": 2}], "hasNextPage": False}}),
            ]
        )
        items = list(client.iter_offset_list("imopenlines.v2.Session.list", {"limit": 1}))
        self.assertEqual([i["id"] for i in items], [1, 2])
        self.assertEqual(client._session.requests[1]["json"]["offset"], 1)


if __name__ == "__main__":
    unittest.main()

import responses

from bitrix24_agent.client import BitrixApiError, BitrixClient

WEBHOOK = "https://example.bitrix24.ru/rest/1/testcode/"


@responses.activate
def test_call_returns_result():
    responses.add(
        responses.POST,
        f"{WEBHOOK}user.current.json",
        json={"result": {"ID": "42"}},
        status=200,
    )
    client = BitrixClient(WEBHOOK)
    assert client.current_user_id() == 42


@responses.activate
def test_call_raises_bitrix_api_error():
    responses.add(
        responses.POST,
        f"{WEBHOOK}tasks.task.list.json",
        json={"error": "NO_AUTH_FOUND", "error_description": "Wrong auth"},
        status=401,
    )
    client = BitrixClient(WEBHOOK)
    try:
        client.call("tasks.task.list")
        assert False, "должно было выброситься исключение"
    except BitrixApiError as exc:
        assert exc.error == "NO_AUTH_FOUND"


@responses.activate
def test_call_list_paginates_plain_array():
    responses.add(
        responses.POST,
        f"{WEBHOOK}crm.activity.list.json",
        json={"result": [{"ID": "1"}, {"ID": "2"}], "next": 2, "total": 3},
        status=200,
    )
    responses.add(
        responses.POST,
        f"{WEBHOOK}crm.activity.list.json",
        json={"result": [{"ID": "3"}], "total": 3},
        status=200,
    )
    client = BitrixClient(WEBHOOK)
    items = list(client.call_list("crm.activity.list", filter_={"PROVIDER_ID": "IMOPENLINES_SESSION"}))
    assert [i["ID"] for i in items] == ["1", "2", "3"]


@responses.activate
def test_call_list_unwraps_tasks_key():
    responses.add(
        responses.POST,
        f"{WEBHOOK}tasks.task.list.json",
        json={"result": {"tasks": [{"id": "8017", "status": "3"}]}, "total": 1},
        status=200,
    )
    client = BitrixClient(WEBHOOK)
    items = list(client.call_list("tasks.task.list", filter_={"RESPONSIBLE_ID": 1}))
    assert items == [{"id": "8017", "status": "3"}]


@responses.activate
def test_call_retries_on_query_limit_exceeded():
    responses.add(
        responses.POST,
        f"{WEBHOOK}user.current.json",
        json={"error": "QUERY_LIMIT_EXCEEDED", "error_description": "too many"},
        status=503,
    )
    responses.add(
        responses.POST,
        f"{WEBHOOK}user.current.json",
        json={"result": {"ID": "7"}},
        status=200,
    )
    client = BitrixClient(WEBHOOK)
    # Ускоряем тест, убирая реальные паузы между повторами.
    import bitrix24_agent.client as client_module

    client_module.time.sleep = lambda *_args, **_kwargs: None

    assert client.current_user_id() == 7

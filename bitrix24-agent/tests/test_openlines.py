import unittest

from b24agent.openlines import aggregate_sessions


def session(**kwargs):
    base = {"id": 1, "source": "livechat", "waitAnswer": 60, "waitClose": 600, "vote": "none"}
    base.update(kwargs)
    return base


class AggregateSessionsTest(unittest.TestCase):
    def test_metrics(self):
        sessions = [
            session(id=1, waitClose=600, waitAnswer=30, vote="like"),
            session(id=2, waitClose=1200, waitAnswer=90, vote="dislike", source="whatsapp"),
            session(id=3, waitClose=900, waitAnswer=60, vote="like"),
        ]
        report = aggregate_sessions(sessions)
        self.assertEqual(report.handled_sessions, 3)
        self.assertEqual(report.avg_resolution_seconds, 900)
        self.assertEqual(report.median_resolution_seconds, 900)
        self.assertEqual(report.avg_first_answer_seconds, 60)
        self.assertEqual(report.likes, 2)
        self.assertEqual(report.dislikes, 1)
        self.assertEqual(report.sessions_by_source, {"livechat": 2, "whatsapp": 1})

    def test_missing_metrics(self):
        report = aggregate_sessions([session(waitClose=None, waitAnswer=None)])
        self.assertEqual(report.handled_sessions, 1)
        self.assertIsNone(report.avg_resolution_seconds)
        self.assertIsNone(report.avg_first_answer_seconds)

    def test_empty(self):
        report = aggregate_sessions([])
        self.assertEqual(report.handled_sessions, 0)
        self.assertTrue(report.available)


if __name__ == "__main__":
    unittest.main()

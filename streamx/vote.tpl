<div class="sx-vote">
	<div class="sx-vote__title">{title}</div>
	[votelist]
	<form method="post" name="vote">
		{list}
		<button class="sx-btn sx-btn--primary sx-btn--sm" type="submit" onclick="doVote('vote'); return false;">Голосовать</button>
		<button class="sx-btn sx-btn--ghost sx-btn--sm" type="button" onclick="doVote('results'); return false;">Результаты</button>
	</form>
	[/votelist]
	[voteresult]
	<div class="sx-vote__result">{list}</div>
	<div class="sx-vote__total">Всего голосов: {votes}</div>
	[/voteresult]
</div>

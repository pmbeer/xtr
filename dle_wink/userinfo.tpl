<div class="profile-page">
	[not-logged]
	<div class="profile-guest">
		<h1 class="profile-guest__title">Личный кабинет</h1>
		<ul class="profile-guest__list">
			<li>Смотрите на 5 устройствах одновременно</li>
			<li>Скачивайте фильмы и сериалы</li>
			<li>Создавайте детские профили</li>
			<li>Настраивайте родительский контроль</li>
			<li>Синхронизация прогресса просмотра</li>
		</ul>
		<a href="{registration-link}" class="btn btn--primary btn--lg">Войти или зарегистрироваться</a>
	</div>
	[/not-logged]
	[logged]
	<div class="profile-card">
		<div class="profile-card__header">
			<div class="profile-card__avatar">{foto}</div>
			<div>
				<h1 class="profile-card__name">{login}</h1>
				<span class="profile-card__group">{group}</span>
			</div>
		</div>
		<div class="profile-card__tabs" data-tabs>
			<button type="button" class="tabs__btn active">Профиль</button>
			<button type="button" class="tabs__btn">Подписка</button>
			<button type="button" class="tabs__btn">Устройства</button>
			<button type="button" class="tabs__btn">Детские профили</button>
		</div>
		<div class="profile-card__body">{edituser}{info}</div>
	</div>
	[/logged]
</div>

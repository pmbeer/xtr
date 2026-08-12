<div class="page-services">
	<div class="container">
		<h1 class="page-header__title">Подписки</h1>
		<div class="tabs" data-tabs>
			<button type="button" class="tabs__btn active" data-tab="all">Все подписки</button>
			<button type="button" class="tabs__btn" data-tab="discount">Со скидкой</button>
			<button type="button" class="tabs__btn" data-tab="services">Сервисы</button>
		</div>
		<div class="plans-grid">
			{custom template="shortstory-subscription" limit="10" cache="yes"}
		</div>
		<div class="page-services__content">{static}</div>
	</div>
</div>

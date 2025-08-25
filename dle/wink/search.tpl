<section class="search-page">
    <h1>Результаты поиска</h1>
    <form class="search-form" action="{search-link}" method="post">
        <input type="text" name="story" value="{searchword}" placeholder="Поиск...">
        <button class="btn btn-secondary" type="submit">Найти</button>
    </form>
    <div class="cards-grid">
        {content}
    </div>
    {include file="navigation.tpl"}
</section>


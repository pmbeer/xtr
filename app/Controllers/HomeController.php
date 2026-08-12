<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\ContentModel;

final class HomeController extends Controller
{
    public function index(): void
    {
        $content = new ContentModel($this->pdo);
        $user = auth_user();
        $continueWatching = $user ? $content->getContinueWatching((int)$user['id']) : [];
        $this->render('home/index', [
            'banners' => $content->getBanners(),
            'newReleases' => $content->getLatestMovies(24),
            'editorsChoice' => $content->getEditorsChoice(24),
            'stsTnt' => $content->getLatestSeries(20),
            'originals' => $content->getOriginals(20),
            'continueWatching' => $continueWatching,
        ]);
    }
}

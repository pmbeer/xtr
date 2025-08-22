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
        $banners = $content->getBanners();
        $featured = $content->getFeatured();
        $movies = $content->getLatestMovies();
        $series = $content->getLatestSeries();
        $kids = $content->getKids();
        $tv = $content->getTvChannels();
        $this->render('home/index', compact('banners', 'featured', 'movies', 'series', 'kids', 'tv'));
    }
}
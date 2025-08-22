<?php

declare(strict_types=1);

namespace Controllers;

use Core\Controller;
use Models\Movie;

final class HomeController extends Controller
{
	public function index(): void
	{
		$featured = Movie::getFeatured(10);
		$trending = Movie::getTrending(12);
		$latest = Movie::getLatest(12);
		$this->view('home', [
			'featured' => $featured,
			'trending' => $trending,
			'latest' => $latest,
		]);
	}
}
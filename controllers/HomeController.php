<?php

declare(strict_types=1);

namespace Controllers;

use Core\Controller;
use Models\Movie;

class HomeController extends Controller
{
	public function index(): void
	{
		$movieModel = new Movie();
		$featured = $movieModel->getFeatured();
		$trending = $movieModel->getTrending();
		$newReleases = $movieModel->getNewReleases();
		$this->view('home', [
			'featured' => $featured,
			'trending' => $trending,
			'newReleases' => $newReleases,
		]);
	}
}
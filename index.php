<?php

declare(strict_types=1);

require __DIR__ . '/core/bootstrap.php';

use Core\Router;

$router = new Router();

// Public routes
$router->get('/', 'HomeController@index');
$router->get('/movies', 'CatalogController@movies');
$router->get('/series', 'CatalogController@series');
$router->get('/channels', 'CatalogController@channels');
$router->get('/kids', 'CatalogController@kids');
$router->get('/search', 'CatalogController@search');

$router->get('/login', 'AuthController@showLogin');
$router->post('/login', 'AuthController@login');
$router->get('/register', 'AuthController@showRegister');
$router->post('/register', 'AuthController@register');
$router->post('/logout', 'AuthController@logout');
$router->get('/password/forgot', 'AuthController@showForgot');
$router->post('/password/forgot', 'AuthController@sendReset');
$router->get('/password/reset', 'AuthController@showReset');
$router->post('/password/reset', 'AuthController@reset');

$router->get('/media/{slug}', 'MediaController@show');
$router->post('/media/{id}/play', 'MediaController@play');
$router->post('/media/{id}/track', 'MediaController@track');

// User cabinet
$router->get('/cabinet', 'UserController@dashboard');
$router->get('/cabinet/history', 'UserController@history');
$router->get('/cabinet/my-list', 'UserController@myList');
$router->post('/cabinet/my-list/toggle', 'UserController@toggleMyList');

// Subscription
$router->get('/subscribe', 'SubscriptionController@show');
$router->post('/subscribe', 'SubscriptionController@create');
$router->post('/webhooks/payment', 'SubscriptionController@webhook');

// Admin routes
$router->group('/admin', function (Router $r) {
	$r->get('', 'Admin\\DashboardController@index');
	$r->get('/login', 'Admin\\AuthController@showLogin');
	$r->post('/login', 'Admin\\AuthController@login');
	$r->post('/logout', 'Admin\\AuthController@logout');

	$r->get('/movies', 'Admin\\MoviesController@index');
	$r->get('/movies/create', 'Admin\\MoviesController@create');
	$r->post('/movies', 'Admin\\MoviesController@store');
	$r->get('/movies/{id}/edit', 'Admin\\MoviesController@edit');
	$r->post('/movies/{id}', 'Admin\\MoviesController@update');
	$r->post('/movies/{id}/delete', 'Admin\\MoviesController@destroy');

	$r->get('/series', 'Admin\\SeriesController@index');
	$r->get('/series/create', 'Admin\\SeriesController@create');
	$r->post('/series', 'Admin\\SeriesController@store');
	$r->get('/series/{id}/edit', 'Admin\\SeriesController@edit');
	$r->post('/series/{id}', 'Admin\\SeriesController@update');
	$r->post('/series/{id}/delete', 'Admin\\SeriesController@destroy');

	$r->get('/users', 'Admin\\UsersController@index');
	$r->get('/users/{id}/edit', 'Admin\\UsersController@edit');
	$r->post('/users/{id}', 'Admin\\UsersController@update');

	$r->get('/subscriptions', 'Admin\\SubscriptionsController@index');
	$r->post('/subscriptions/{id}/cancel', 'Admin\\SubscriptionsController@cancel');

	$r->get('/stats', 'Admin\\StatsController@index');
});

$router->dispatch(); 

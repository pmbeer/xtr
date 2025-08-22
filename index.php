<?php

declare(strict_types=1);

// Front Controller
// Initializes the application and dispatches the request

require __DIR__ . '/core/bootstrap.php';

use Core\Router;

$router = new Router();

// Public routes
$router->get('/', 'HomeController@index');
$router->get('/movies', 'ContentController@movies');
$router->get('/series', 'ContentController@series');
$router->get('/tv', 'ContentController@tv');
$router->get('/kids', 'ContentController@kids');
$router->get('/search', 'ContentController@search');
$router->get('/movie', 'ContentController@movie');
$router->get('/series/view', 'ContentController@seriesView');

// Auth routes
$router->get('/login', 'AuthController@loginForm');
$router->post('/login', 'AuthController@login');
$router->get('/register', 'AuthController@registerForm');
$router->post('/register', 'AuthController@register');
$router->post('/logout', 'AuthController@logout');
$router->get('/password/forgot', 'AuthController@forgotForm');
$router->post('/password/forgot', 'AuthController@forgot');
$router->get('/password/reset', 'AuthController@resetForm');
$router->post('/password/reset', 'AuthController@reset');

// Subscription/payment stub
$router->get('/subscribe', 'SubscriptionController@plans');
$router->post('/subscribe/checkout', 'SubscriptionController@checkout');
$router->get('/subscribe/success', 'SubscriptionController@success');

// Admin routes
$router->get('/admin', 'AdminController@dashboard');
$router->get('/admin/movies', 'AdminController@movies');
$router->post('/admin/movies/create', 'AdminController@createMovie');
$router->post('/admin/movies/update', 'AdminController@updateMovie');
$router->post('/admin/movies/delete', 'AdminController@deleteMovie');
$router->get('/admin/users', 'AdminController@users');
$router->post('/admin/users/update', 'AdminController@updateUser');
$router->get('/admin/subscriptions', 'AdminController@subscriptions');

$router->dispatch($_SERVER['REQUEST_METHOD'], parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/'); 

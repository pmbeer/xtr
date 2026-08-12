<?php
declare(strict_types=1);

namespace App\Controllers;

use Core\Controller;
use App\Models\ContentModel;

final class KidsController extends Controller
{
    public function index(): void
    {
        $model = new ContentModel($this->pdo);
        $items = $model->listKids();
        $this->render('catalog/index', ['title' => 'Детский раздел', 'items' => $items]);
    }
}
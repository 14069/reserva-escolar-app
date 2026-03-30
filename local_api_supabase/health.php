<?php
require_once 'response.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    jsonResponse(false, 'Método não permitido.', null, 405);
}

jsonResponse(true, 'healthy', [
    'status' => 'ok',
]);

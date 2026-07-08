<?php
/*
 * @copyright Copyright (c) 2022, Afterlogic Corp.
 * @license AGPL-3.0
 *
 * This code is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License, version 3,
 * as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License, version 3,
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

header("Access-Control-Allow-Origin: *");
header('Access-Control-Allow-Credentials: true');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_METHOD'])) {
        // may also be using PUT, PATCH, HEAD etc
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    }

    if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'])) {
        header("Access-Control-Allow-Headers: {$_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']}");
    }

    exit(0);
}

include_once 'system/autoload.php';

$oIntegrator = \Aurora\System\Managers\Integrator::getInstance();
$sQueryString = isset($_SERVER['QUERY_STRING']) ? \urldecode((string) $_SERVER['QUERY_STRING']) : '';
$isMobileVersion = \array_key_exists('mobile-version', $_GET)
	|| false !== \strpos($sQueryString, 'mobile-version');
$isMobileAppRequest = isset($_SERVER['HTTP_X_MOBILEAPP']) && '1' === (string) $_SERVER['HTTP_X_MOBILEAPP'];

// Keep aurora-mobile in sync for Vue mobile entry without clearing the cookie on /.
if ($isMobileVersion || $isMobileAppRequest) {
    $oIntegrator->setMobile(true);
}

\Aurora\System\Application::Start();
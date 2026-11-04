-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 04, 2026 at 04:53 AM
-- Server version: 10.11.16-MariaDB
-- PHP Version: 8.5.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `shelflife_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `global_products`
--

CREATE TABLE `global_products` (
  `product_id` int(11) NOT NULL,
  `barcode` varchar(50) NOT NULL,
  `product_name` varchar(100) NOT NULL,
  `category` varchar(50) NOT NULL DEFAULT 'General',
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `global_products`
--

INSERT INTO `global_products` (`product_id`, `barcode`, `product_name`, `category`, `created_by`, `created_at`) VALUES
(1, '8850123456789', 'Fresh Milk 1L', 'Food', 1, '2026-11-03 13:27:43'),
(2, '8850111222333', 'Paracetamol 500mg (10s)', 'Medicine', 1, '2026-11-03 13:27:43');

-- --------------------------------------------------------

--
-- Table structure for table `inventory_items`
--

CREATE TABLE `inventory_items` (
  `item_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `barcode` varchar(50) DEFAULT NULL,
  `product_name` varchar(100) NOT NULL,
  `category` varchar(50) NOT NULL DEFAULT 'General',
  `quantity` int(11) NOT NULL DEFAULT 1,
  `expiration_date` date NOT NULL,
  `status` enum('active','consumed','discarded') NOT NULL DEFAULT 'active',
  `status_updated_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `inventory_items`
--

INSERT INTO `inventory_items` (`item_id`, `user_id`, `barcode`, `product_name`, `category`, `quantity`, `expiration_date`, `status`, `status_updated_at`, `created_at`, `updated_at`) VALUES
(1, 1, '8850123456789', 'Fresh Milk', 'Food', 2, '2026-11-05', 'active', NULL, '2026-11-03 13:27:43', '2026-11-03 13:27:43'),
(2, 1, '8850111222333', 'Paracetamol 500mg', 'Medicine', 1, '2026-11-10', 'active', NULL, '2026-11-03 13:27:43', '2026-11-03 13:27:43'),
(3, 1, '8850444555666', 'Instant Noodles', 'Food', 5, '2026-10-20', 'active', NULL, '2026-11-03 13:27:43', '2026-11-03 13:27:43'),
(4, 1, '8850777888999', 'Eggs 10s', 'Food', 1, '2026-11-15', 'active', NULL, '2026-11-03 13:28:54', '2026-11-03 13:28:54');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('user','admin') NOT NULL DEFAULT 'user',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `username`, `password_hash`, `role`, `created_at`, `updated_at`) VALUES
(1, 'tom123', 'hashed_pass_here', 'admin', '2026-11-03 13:27:43', '2026-11-03 13:27:43'),
(2, 'sarah', 'hashed_pass_here', 'user', '2026-11-03 13:27:43', '2026-11-03 13:27:43');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `global_products`
--
ALTER TABLE `global_products`
  ADD PRIMARY KEY (`product_id`),
  ADD UNIQUE KEY `barcode` (`barcode`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `inventory_items`
--
ALTER TABLE `inventory_items`
  ADD PRIMARY KEY (`item_id`),
  ADD KEY `idx_user_status` (`user_id`,`status`),
  ADD KEY `idx_exp_date` (`expiration_date`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `global_products`
--
ALTER TABLE `global_products`
  MODIFY `product_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `inventory_items`
--
ALTER TABLE `inventory_items`
  MODIFY `item_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `global_products`
--
ALTER TABLE `global_products`
  ADD CONSTRAINT `global_products_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Constraints for table `inventory_items`
--
ALTER TABLE `inventory_items`
  ADD CONSTRAINT `inventory_items_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

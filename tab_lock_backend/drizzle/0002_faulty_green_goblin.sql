CREATE TABLE `mesh_relay_messages` (
	`id` int AUTO_INCREMENT NOT NULL,
	`fromDeviceId` varchar(128) NOT NULL,
	`toDeviceId` varchar(128) NOT NULL,
	`tokenHash` varchar(128) NOT NULL,
	`envelope` text NOT NULL,
	`expiresAt` timestamp NOT NULL,
	`delivered` int NOT NULL DEFAULT 0,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `mesh_relay_messages_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `mesh_sessions` (
	`id` int AUTO_INCREMENT NOT NULL,
	`deviceId` varchar(128) NOT NULL,
	`peerId` varchar(128) NOT NULL,
	`tokenHash` varchar(128) NOT NULL,
	`expiresAt` timestamp NOT NULL,
	`revoked` int NOT NULL DEFAULT 0,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `mesh_sessions_id` PRIMARY KEY(`id`)
);

CREATE TABLE `tab_lock_devices` (
	`id` int AUTO_INCREMENT NOT NULL,
	`groupId` varchar(128) NOT NULL,
	`deviceId` varchar(128) NOT NULL,
	`deviceType` varchar(32) NOT NULL,
	`deviceName` varchar(160) NOT NULL,
	`accessTokenHash` varchar(128) NOT NULL,
	`pairCodeHash` varchar(128),
	`paired` int NOT NULL DEFAULT 0,
	`revoked` int NOT NULL DEFAULT 0,
	`expiresAt` timestamp NOT NULL,
	`lastSeenAt` timestamp,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `tab_lock_devices_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `tab_lock_groups` (
	`id` int AUTO_INCREMENT NOT NULL,
	`groupId` varchar(128) NOT NULL,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `tab_lock_groups_id` PRIMARY KEY(`id`),
	CONSTRAINT `tab_lock_groups_groupId_unique` UNIQUE(`groupId`)
);
--> statement-breakpoint
CREATE TABLE `tab_lock_policies` (
	`id` int AUTO_INCREMENT NOT NULL,
	`groupId` varchar(128) NOT NULL,
	`domain` varchar(253) NOT NULL,
	`mode` varchar(16) NOT NULL,
	`unlockSalt` varchar(128),
	`unlockVerifier` varchar(128),
	`failurePage` varchar(32) NOT NULL DEFAULT 'blocked',
	`relockOnRefresh` int NOT NULL DEFAULT 1,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `tab_lock_policies_id` PRIMARY KEY(`id`)
);

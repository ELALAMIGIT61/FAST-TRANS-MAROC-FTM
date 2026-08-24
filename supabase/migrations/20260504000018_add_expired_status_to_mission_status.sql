-- Migration 20260504000018
-- Ajout du statut expired a l'enum mission_status
-- Session 2.14 quinquies, Volet 2 de la Piste Diffusion - expiration d'une
-- mission pending dont scheduled_pickup_time est depasse, sans acceptation
--
-- NOTE TECHNIQUE : cette migration ne contient QUE cet ALTER TYPE, sans
-- aucune autre instruction. PostgreSQL interdit d'utiliser une nouvelle
-- valeur d'enum dans la meme transaction ou elle a ete ajoutee.

ALTER TYPE mission_status ADD VALUE IF NOT EXISTS 'expired';

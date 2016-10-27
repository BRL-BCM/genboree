{\rtf1\mac\ansicpg10000\cocoartf824\cocoasubrtf480
{\fonttbl\f0\fswiss\fcharset77 Helvetica-Bold;\f1\fswiss\fcharset77 Helvetica;}
{\colortbl;\red255\green255\blue255;}
\margl1440\margr1440\vieww19980\viewh13780\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\ql\qnatural\pardirnatural

\f0\b\fs24 \cf0 DROP TABLE if exists data_acquisition_complete;
\f1\b0 \
\

\f0\b CREATE TABLE data_acquisition_complete\
\{\
	db_name			VARCHAR (30) NOT NULL,\
	remote_track_name	VARCHAR (41) NOT NULL,\
	class_name			VARCHAR (40) NOT NULL,\
	host				VARCHAR (60) NOT NULL, \
	file_to_download		VARCHAR (60) NOT NULL,\
	d_directory_output	VARCHAR (100) NOT NULL,\
	converter_name		VARCHAR (60) NOT NULL,\
	file_to_output		VARCHAR (60) NOT NULL,\
	c_directory_output	VARCHAR (100) NOT NULL,\
	PRIMARY KEY		(db_name, remote_track_name)\
\};\
\
INSERT INTO data_acquisition_complete (db_name, remote_track_name, class_name,host,file_to_download,d_directory_output,converter_name,file_to_output,c_directory_output) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);\
\
SELECT data_acquisition_complete.db_name, data_acquisition_complete.remote_track_name\
FROM data_acquisition_complete\
WHERE data_acquisition_complete.db_name = 'USER_SELECTED_DATABASE_NAME (i.e. hg18)';\
\
SELECT data_acquisition_complete.remote_track_name, data_acquisition_complete.class_name, data_acquisition_complete.host, data_acquisition_complete.file_to_download, data_acquisition_complete.d_directory_output, data_acquisition_complete.converter_name, data_acquisition_complete.file_to_output, data_acquisition_complete.c_directory_output\
FROM data_acquisition_complete\
WHERE data_acquisition_complete.db_name = 'USER_SELECTED_DATABASE_NAME (i.e. hg18)' AND data_acquisition_complete.remote_track_name = 'USER_INPUT_TRACK_NAME (i.e. Fosmid:EndPairs)';}
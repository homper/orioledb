/*-------------------------------------------------------------------------
 *
 * seq_buf.h
 *		Decalarations for sequential buffered data access routines.
 *
 * Copyright (c) 2021-2025, Oriole DB Inc.
 *
 * IDENTIFICATION
 *	  contrib/orioledb/include/utils/seq_buf.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef __SEQ_BUF_H__
#define __SEQ_BUF_H__

typedef enum
{
	SeqBufPrevPageDone,
	SeqBufPrevPageInProgress,
	SeqBufPrevPageError
} SeqBufPrevPageState;

typedef struct
{
	Oid			datoid;
	Oid			relnode;
	uint32		num;
	char		type;
} SeqBufTag;

#define SeqBufTagEqual(l, r) ((l)->datoid == (r)->datoid && \
							  (l)->relnode == (r)->relnode && \
							  (l)->num == (r)->num && \
							  (l)->type == (r)->type)

typedef struct
{
	slock_t		lock;			/* spinlock protecting the fields below */
	OInMemoryBlkno pages[2];	/* pages with data */
	int			location;
	int			curPageNum;		/* current page in usage from previous two */
	uint32		filePageNum;	/* file page currently loaded */
	off_t		freeBytesNum;	/* how many unread bytes left in a file */
	off_t		evictOffset;
	SeqBufTag	tag;
	SeqBufPrevPageState prevPageState;
} SeqBufDescShared;

#define SEQ_BUF_SHARED_EXIST(shared_ptr) (OInMemoryBlknoIsValid((shared_ptr)->pages[0]))

typedef struct
{
	SeqBufDescShared *shared;
	File		file;
	SeqBufTag	tag;
	bool		write;
} SeqBufDescPrivate;

typedef struct
{
	off_t		offset;
	SeqBufTag	tag;
} EvictedSeqBufData;

typedef enum
{
	SeqBufReplaceSuccess,
	SeqBufReplaceAlready,
	SeqBufReplaceError
} SeqBufReplaceResult;

extern bool init_seq_buf(SeqBufDescPrivate *seqBufPrivate, SeqBufDescShared *shared,
						 SeqBufTag *tag, bool write, bool init_shared, int skip_len, EvictedSeqBufData *evicted);

extern bool seq_buf_write_u32(SeqBufDescPrivate *seqBufPrivate, uint32 offset);
extern bool seq_buf_read_u32(SeqBufDescPrivate *seqBufPrivate, uint32 *ptr);
extern bool seq_buf_write_file_extent(SeqBufDescPrivate *seqBufPrivate, FileExtent extent);
extern bool seq_buf_read_file_extent(SeqBufDescPrivate *seqBufPrivate, FileExtent *extent);

extern uint64 seq_buf_finalize(SeqBufDescPrivate *seqBufPrivate);
extern char *get_seq_buf_filename(SeqBufTag *tag);
extern uint64 seq_buf_get_offset(SeqBufDescPrivate *seqBufPrivate);
extern SeqBufReplaceResult seq_buf_try_replace(SeqBufDescPrivate *seqBufPrivate,
											   SeqBufTag *tag, pg_atomic_uint64 *size,
											   Size data_size);
extern bool seq_buf_file_exist(SeqBufTag *tag);
extern bool seq_buf_remove_file(SeqBufTag *tag);
extern void seq_buf_close_file(SeqBufDescPrivate *seqBufPrivate);

#endif							/* __SEQ_BUF_H__ */

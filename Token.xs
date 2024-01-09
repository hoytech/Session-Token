#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "standard.h"
#include "rand.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>


struct session_token_ctx {
  int mask;
  int count;
  int curr_word;
  int bytes_left_in_curr_word;
  struct randctx isaac_ctx;
  char *alphabet;
  size_t alphabet_length;
  size_t token_length;
};

typedef struct session_token_ctx * Session_Token;

static inline int get_new_byte(struct session_token_ctx *ctx) {
  int output;

  if (ctx->bytes_left_in_curr_word == 0) {
    if (ctx->count > 255) {
      isaac(&ctx->isaac_ctx);
      ctx->count = 0;
    }

    ctx->curr_word = ctx->isaac_ctx.randrsl[ctx->count];
    ctx->count++;
    ctx->bytes_left_in_curr_word = 4;
  }

  output = ctx->curr_word & 0xFF;
  ctx->bytes_left_in_curr_word--;
  ctx->curr_word >>= 8;

  return output;
}

static int get_mask(int v) {
  v--;
  v |= v >> 1;
  v |= v >> 2;
  v |= v >> 4;
  return v;
}


MODULE = Session::Token		PACKAGE = Session::Token		

PROTOTYPES: ENABLE


Session_Token
_new_context(seed, alphabet, token_length)
        SV *seed
        SV *alphabet
        size_t token_length
    CODE:
        struct session_token_ctx *ctx;
        char *seedp;
        size_t len;

        len = SvCUR(seed);
        seedp = SvPV(seed, len);

        assert(sizeof(ctx->isaac_ctx.randrsl) == 1024);

        if (len != 1024) {
          croak("unexpected seed length: %lu", len);
        }

        ctx = malloc(sizeof(struct session_token_ctx));
        memset(ctx, '\0', sizeof(struct session_token_ctx));

        memcpy(&ctx->isaac_ctx.randrsl, seedp, 1024);
        randinit(&ctx->isaac_ctx, TRUE);
        isaac(&ctx->isaac_ctx);

        ctx->alphabet_length = SvCUR(alphabet);
        ctx->alphabet = malloc(ctx->alphabet_length);
        memcpy(ctx->alphabet, SvPV(alphabet, ctx->alphabet_length), ctx->alphabet_length);

        ctx->token_length = token_length;

        ctx->mask = get_mask(ctx->alphabet_length);

        RETVAL = ctx;

    OUTPUT:
        RETVAL


void
DESTROY(ctx)
        Session_Token ctx
    CODE:
        free(ctx->alphabet);
        free(ctx);


SV *
get(ctx)
        Session_Token ctx
    CODE:
        SV *output;
        char *outputp;
        size_t i, curr;

        output = newSVpvn("", 0);
        SvGROW(output, ctx->token_length + 1);
        SvCUR_set(output, ctx->token_length);
        outputp = SvPV_nolen(output);

        for (i=0; i<ctx->token_length; i++) {
          while((curr = (get_new_byte(ctx) & ctx->mask)) >= ctx->alphabet_length)  ;
          outputp[i] = ctx->alphabet[curr];
        }
        outputp[i] = '\0';

        RETVAL = output;

    OUTPUT:
        RETVAL


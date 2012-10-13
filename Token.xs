#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "standard.h"
#include "rand.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>


struct session_token_ctx {
  int count;
  int curr_word;
  int bytes_left_in_curr_word;
  struct randctx isaac_ctx;
};

static int get_new_byte(struct session_token_ctx *ctx) {
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


unsigned long
_get_isaac_context(seed)
        SV *seed
    CODE:
        struct session_token_ctx *ctx;
        char *seedp;
        size_t len;

        len = SvCUR(seed);
        seedp = SvPV(seed, len);

        assert(sizeof(ctx->isaac_ctx.randrsl) == 1024);

        if (SvCUR(seed) != 1024) {
          XSRETURN_UNDEF;
        }

        ctx = malloc(sizeof(struct session_token_ctx));
        memset(ctx, '\0', sizeof(struct session_token_ctx));

        memcpy(&ctx->isaac_ctx.randrsl, seedp, 1024);
        randinit(&ctx->isaac_ctx, TRUE);
        isaac(&ctx->isaac_ctx);

        RETVAL = (unsigned long) ctx;

    OUTPUT:
        RETVAL


void
_destroy_isaac_context(ctx)
        unsigned long ctx
    CODE:
        free((void*) ctx);


void
_get_token(ctx_raw, alphabet, output)
        unsigned long ctx_raw
        SV *alphabet
        SV *output
    CODE:
        struct session_token_ctx *ctx;
        char *alphabetp;
        size_t alphabetlen;
        char *outputp;
        size_t outputlen;
        int i, curr, mask;

        ctx = (struct session_token_ctx *) ctx_raw;

        alphabetlen = SvCUR(alphabet);
        alphabetp = SvPV(alphabet, alphabetlen);

        outputlen = SvCUR(output);
        outputp = SvPV(output, outputlen);

        mask = get_mask(alphabetlen);

        for (i=0; i<outputlen; i++) {
          while((curr = (get_new_byte(ctx) & mask)) >= alphabetlen)  ;
          outputp[i] = alphabetp[curr];
        }

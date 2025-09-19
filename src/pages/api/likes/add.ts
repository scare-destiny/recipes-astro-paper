
// src/pages/api/likes/add.ts
import type { APIRoute } from 'astro';
import { createClient } from '@supabase/supabase-js';

export const prerender = false;

const supabase = createClient(
  import.meta.env.PUBLIC_SUPABASE_URL,
  import.meta.env.PUBLIC_SUPABASE_ANON_KEY
);

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    console.log('Request body:', body);
    
    const { slug } = body;
    
    if (!slug) {
      console.error('No slug provided');
      return new Response(JSON.stringify({ error: 'Slug is required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    console.log('Adding like for slug:', slug);

    // Add the like
    const { error: insertError } = await supabase
      .from('post_likes')
      .insert({ post_slug: slug });

    if (insertError) {
      console.error('Error inserting like:', insertError);
      return new Response(JSON.stringify({ error: 'Failed to add like', details: insertError.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Get updated count
    const { count, error: countError } = await supabase
      .from('post_likes')
      .select('*', { count: 'exact', head: true })
      .eq('post_slug', slug);

    if (countError) {
      console.error('Error getting count:', countError);
      return new Response(JSON.stringify({ error: 'Failed to get updated count' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ 
      success: true, 
      likes: count || 0 
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache'
      }
    });
  } catch (error) {
    console.error('Error in add like endpoint:', error);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
};
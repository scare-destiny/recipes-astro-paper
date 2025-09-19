
// src/pages/api/likes/add.ts
import type { APIRoute } from 'astro';
import { createClient } from '@supabase/supabase-js';

export const prerender = false;

const supabase = createClient(
  import.meta.env.PUBLIC_SUPABASE_URL,
  import.meta.env.PUBLIC_SUPABASE_ANON_KEY
);

export const POST: APIRoute = async ({ request, clientAddress }) => {
  try {
    const body = await request.json();
    console.log('Request body:', body);
    
    const { slug, analytics } = body;
    
    if (!slug) {
      console.error('No slug provided');
      return new Response(JSON.stringify({ error: 'Slug is required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    console.log('Adding like for slug:', slug);

    // Get geolocation data
    let locationData: any = {};
    try {
      const ip = clientAddress || '127.0.0.1';
      const geoResponse = await fetch(`http://ip-api.com/json/${ip}?fields=status,country,countryCode,region,regionName,city,timezone,query`);
      if (geoResponse.ok) {
        locationData = await geoResponse.json();
      }
    } catch (geoError) {
      console.log('Geolocation fetch failed:', geoError);
    }

    // Prepare like data with analytics
    const likeData = {
      post_slug: slug,
      user_agent: analytics?.userAgent || null,
      ip_address: clientAddress || null,
      country: locationData.country || null,
      city: locationData.city || null,
      region: locationData.regionName || null,
      timezone: analytics?.timezone || locationData.timezone || null,
      referrer: analytics?.referrer || null,
      language: analytics?.language || null,
      // analytics_data: analytics ? JSON.stringify(analytics) : null
    };

    console.log('Like data:', likeData);

    // Add the like
    const { error: insertError } = await supabase
      .from('post_likes')
      .insert(likeData);

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
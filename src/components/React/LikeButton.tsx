import React, { useState, useEffect, useRef } from 'react';
import '@/components/React/LikeButton.css'
import type { TablesInsert, Tables } from '@/../database.types';

// Use database types for analytics data
type AnalyticsData = Pick<TablesInsert<'post_likes'>, 'user_agent' | 'language' | 'referrer' | 'timezone'> & {
  screenResolution: string;
  timestamp: string;
};

interface LikeResponse {
  success?: boolean;
  likes: number;
  error?: string;
  message?: string;
}

interface LikeButtonProps {
  slug: string;
}

export default function LikeButton({ slug }: LikeButtonProps) {
  const [likes, setLikes] = useState<number>(0);
  const [isLiking, setIsLiking] = useState<boolean>(false);
  const [error, setError] = useState<string>('');
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const countRef = useRef<HTMLSpanElement>(null);

  // Fetch initial like count - runs on every component mount
  useEffect(() => {
    const fetchLikeCount = async (): Promise<void> => {
      try {
        // Always use fresh timestamp to bypass any caching
        const timestamp: number = Date.now();
        const response: Response = await fetch(`/api/likes/${encodeURIComponent(slug)}?t=${timestamp}&fresh=${Math.random()}`, {
          cache: 'no-store', // Force no caching
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
          }
        });
        
        console.log('Fetching fresh like count for:', slug, 'Status:', response.status);
        
        if (response.ok) {
          const data: LikeResponse = await response.json();
          setLikes(data.likes);
          console.log('Fresh like count loaded:', data.likes);
        } else {
          setLikes(0);
        }
      } catch (error: unknown) {
        console.error('Error fetching like count:', error);
        setLikes(0);
      } finally {
        setIsLoading(false);
      }
    };

    // Always fetch fresh data on mount
    fetchLikeCount();
  }, [slug]); // Re-run when slug changes

  const handleLike = async (): Promise<void> => {
    if (isLiking) return;
    
    console.log('Like button clicked, slug:', slug);
    setIsLiking(true);
    setError('');
    
    // Immediate visual feedback
    if (buttonRef.current) {
      buttonRef.current.classList.add('clicked', 'liked');
    }
    if (countRef.current) {
      countRef.current.classList.add('updating');
    }
    
    try {
      console.log('Sending POST request to /api/likes/add');
      
      // Collect analytics data
      const analyticsData: AnalyticsData = {
        user_agent: navigator.userAgent,
        language: navigator.language,
        referrer: document.referrer,
        screenResolution: `${screen.width}x${screen.height}`,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        timestamp: new Date().toISOString()
      };
      
      const response: Response = await fetch('/api/likes/add', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          slug: slug,
          analytics: analyticsData
        }),
      });

      console.log('Response status:', response.status, response.statusText);

      if (response.ok) {
        const data: LikeResponse = await response.json();
        console.log('Like added successfully:', data);
        
        // Animate count update
        setTimeout(() => {
          setLikes(data.likes);
          if (countRef.current) {
            countRef.current.style.animation = 'countUp 0.4s ease';
          }
        }, 100);
        
        // Reset animation classes
        setTimeout(() => {
          if (countRef.current) {
            countRef.current.classList.remove('updating');
            countRef.current.style.animation = '';
          }
        }, 400);
        
      } else {
        // Revert on error
        if (buttonRef.current) {
          buttonRef.current.classList.remove('liked');
        }
        const errorData: LikeResponse = await response.json().catch(() => ({ 
          message: 'Unable to add like. Please try again.',
          likes: 0
        }));
        console.error('Failed to add like:', response.status, response.statusText, errorData);
        
        // Show user-friendly error message from server or fallback
        setError(errorData.message || 'Unable to add like. Please try again.');
      }
    } catch (error: unknown) {
      // Revert on error
      if (buttonRef.current) {
        buttonRef.current.classList.remove('liked');
      }
      console.error('Error adding like:', error);
      
      // Show user-friendly error message
      setError('Connection error. Please check your internet and try again.');
    } finally {
      setIsLiking(false);
      // Remove clicked class after animation
      setTimeout(() => {
        if (buttonRef.current) {
          buttonRef.current.classList.remove('clicked');
        }
      }, 600);
    }
  };

  if (isLoading) {
    return (
      <div className="like-button-container">
        <div className="like-button loading">
          <svg width="24" height="20" viewBox="0 0 50 42" fill="none" className="heart-icon">
            <path 
              className="heart-path"
              d="M13.2537 0.0255029C23.4033 0.0255029 25.0273 10.5191 25.0273 10.5191C25.0273 10.5191 26.6512 -0.60088 37.6129 0.0255029C44.3441 0.410148 48.7484 6.32169 48.9804 12.1981C49.7924 32.7656 28.7678 41.5 25.0273 41.5C21.2868 41.5 -0.549833 32.3459 1.07416 12.1981C1.54782 6.32169 6.29929 0.0255029 13.2537 0.0255029Z" 
              fill="url(#inactive-gradient-loading)"
            />
          </svg>
        </div>
        <span className="like-count">...</span>
      </div>
    );
  }

  return (
    <div className="like-button-container">
      <button 
        ref={buttonRef}
        className="like-button" 
        aria-label="Like this post"
        onClick={handleLike}
        disabled={isLiking}
      >
        <svg width="24" height="20" viewBox="0 0 50 42" fill="none" className="heart-icon">
          <defs>
            <linearGradient id={`active-gradient-${slug}`} x1="25" y1="42" x2="26.3796" y2="0.0453673" gradientUnits="userSpaceOnUse">
              <stop stopColor="hsl(353deg, 100%, 52%)"></stop>
              <stop offset="1" stopColor="hsl(313deg, 100%, 52%)"></stop>
            </linearGradient>
            <linearGradient id={`inactive-gradient-${slug}`} x1="15" y1="41" x2="42" y2="-1.5" gradientUnits="userSpaceOnUse">
              <stop stopColor="#666" stopOpacity="0.8"></stop>
              <stop offset="1" stopColor="#999" stopOpacity="0.8"></stop>
            </linearGradient>
          </defs>
          <path 
            className="heart-path"
            d="M13.2537 0.0255029C23.4033 0.0255029 25.0273 10.5191 25.0273 10.5191C25.0273 10.5191 26.6512 -0.60088 37.6129 0.0255029C44.3441 0.410148 48.7484 6.32169 48.9804 12.1981C49.7924 32.7656 28.7678 41.5 25.0273 41.5C21.2868 41.5 -0.549833 32.3459 1.07416 12.1981C1.54782 6.32169 6.29929 0.0255029 13.2537 0.0255029Z" 
            fill={`url(#inactive-gradient-${slug})`}
          />
        </svg>
      </button>
      <span ref={countRef} className="like-count">
        {likes.toLocaleString()}
      </span>
      {error && (
        <div className="like-error-message">
          {error}
        </div>
      )}
    </div>
  );
}

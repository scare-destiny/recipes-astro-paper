import image from '@/assets/images/Eugene_Venger.jpg';
// import { FadeIn, FadeInStagger } from '~/components/react/Animations/FadeIn';

export default function About() {
  return (
    <div className="grid grid-cols-1 gap-y-16 lg:grid-cols-2 lg:grid-rows-[auto_1fr] lg:gap-y-12">
      <div className="lg:pl-20">
        <div className="max-w-lg px-2.5 lg:max-w-none  ">
          <img
            src={image.src}
            alt=""
            sizes="(min-width: 1024px) 32rem, 20rem"
            className="aspect-square rotate-3 rounded-2xl bg-zinc-100 object-cover dark:bg-zinc-800 animate-in slide-in-from-right fade-in-50  duration-1000"
          />
        </div>
      </div>
      <div className="lg:order-first lg:row-span-2">
        {/* <FadeIn> */}
        <h1 className="text-4xl font-bold tracking-tight text-zinc-800 dark:text-zinc-100 sm:text-5xl">
          {/* Welcome to my space! */}
        </h1>
        {/* </FadeIn> */}
        <div className="mt-6 space-y-7 text-base text-zinc-600 dark:text-zinc-400">
          <p>
            Work in progress :)
          </p>
    
        </div>
      </div>
    </div>
  );
}

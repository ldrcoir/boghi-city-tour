"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";

const APK_PATH = "/apk/BoghiCityTour_v0.3_test.apk";

const SCREENSHOTS = [
  { src: "/apk/shot_menu_v6.png", alt: "منو با لوگوی رسمی و حباب گفتار بوقی — ماشین‌ها حرف می‌زنند!" },
  { src: "/apk/shot_garage_v6a.png", alt: "کارگاه استاد فنر با حباب گفتار ماشین و جرقه‌های تعمیر" },
  { src: "/apk/shot_garage_v6b.png", alt: "استاد فنر سیبیل‌دار وسط کار — گاراژ زنده و پرحرف" },
  { src: "/apk/shot_game_v5.png", alt: "گیم‌پلی: بوقی قرمز با چشم‌های خوشگل و نیترو در تهران" },
];

const STEPS = [
  { n: "۱", t: "دانلود", d: "دکمه بزرگ نارنجی را بزن تا فایل APK (۷۰ مگابایت) دانلود شود." },
  { n: "۲", t: "اجازه نصب", d: "روی فایل دانلودشده بزن؛ اگر پرسید، «اجازه نصب از منابع ناشناس» را برای مرورگرت فعال کن." },
  { n: "۳", t: "بازی!", d: "نصب که تمام شد آیکون بوقی قرمز را از منوی گوشی باز کن و اسم بچه را بنویس — سفر شروع می‌شود!" },
];

export default function Home() {
  const [downloading, setDownloading] = useState(false);

  const startDownload = () => {
    setDownloading(true);
    setTimeout(() => setDownloading(false), 4000);
  };

  return (
    <main
      className="min-h-screen flex flex-col text-amber-50"
      style={{
        background:
          "linear-gradient(180deg,#2a1208 0%,#4a1d0a 38%,#7c2d12 72%,#b45309 100%)",
      }}
    >
      <div className="flex-1 w-full max-w-3xl mx-auto px-4 pt-10 pb-6">
        {/* هدر */}
        <header className="text-center mb-8">
          <div className="inline-block rounded-3xl bg-amber-950/40 border-2 border-amber-500/30 p-3 shadow-2xl shadow-black/40 mb-4">
            <img
              src="/apk/logo_card.png"
              alt="لوگوی رسمی بوقی: تور شهرها — ماشین قرمز زنده با چشم‌های آبی و لبخند بزرگ، از استودیو ایماروید"
              className="w-[300px] sm:w-[360px] rounded-2xl"
            />
          </div>
          <h1 className="font-display-fa text-4xl sm:text-5xl text-amber-300 drop-shadow-[0_3px_0_rgba(0,0,0,0.5)]">
            بوقی: تور شهرها
          </h1>
          <p className="mt-2 text-amber-100/85 text-sm sm:text-base leading-7 max-w-md mx-auto">
            فصل ۱ تهران — ۵۰ مأموریت با ماشین‌های زبان‌باز، نیترو، کارگاه استاد فنر و
            ۱۲ ماشین ایرانی با شخصیت
          </p>
        </header>

        {/* کارت دانلود */}
        <section
          aria-label="دانلود فایل نصب"
          className="rounded-3xl border-2 border-amber-400/25 bg-amber-950/45 backdrop-blur-sm p-6 shadow-2xl shadow-black/50"
        >
          <div className="flex flex-wrap items-center justify-center gap-2 text-xs text-amber-200/90 mb-5">
            <span className="rounded-full bg-amber-500/15 border border-amber-400/30 px-3 py-1">
              نسخه ۰.۳.۰ (تست خانوادگی)
            </span>
            <span className="rounded-full bg-amber-500/15 border border-amber-400/30 px-3 py-1">
              ۷۰ مگابایت
            </span>
            <span className="rounded-full bg-amber-500/15 border border-amber-400/30 px-3 py-1">
              اندروید ۷ به بالا
            </span>
          </div>

          <div className="text-center">
            <a href={APK_PATH} download onClick={startDownload}>
              <Button
                size="lg"
                className="font-display-fa text-2xl sm:text-3xl h-16 sm:h-[4.5rem] px-10 sm:px-14 rounded-2xl text-amber-50 shadow-xl shadow-orange-950/60 border-b-4 border-orange-900/70 transition-transform hover:scale-[1.03] active:scale-[0.98] min-w-[240px]"
                style={{
                  background: "linear-gradient(180deg,#f59e0b 0%,#ea580c 55%,#c2410c 100%)",
                }}
              >
                {downloading ? "در حال دانلود… 🚗💨" : "⬇ دانلود نسخه تست"}
              </Button>
            </a>
            <p className="mt-3 text-xs text-amber-200/70">
              فایل نصبی رسمی تست — فقط برای خانواده ما!
            </p>
          </div>

          {/* مراحل نصب */}
          <ol className="mt-7 space-y-3">
            {STEPS.map((s) => (
              <li
                key={s.n}
                className="flex items-start gap-3 rounded-2xl bg-black/25 border border-amber-400/15 p-4"
              >
                <span
                  className="font-display-fa shrink-0 w-9 h-9 rounded-full flex items-center justify-center text-lg text-orange-950"
                  style={{ background: "linear-gradient(180deg,#fbbf24,#f59e0b)" }}
                  aria-hidden
                >
                  {s.n}
                </span>
                <div>
                  <p className="font-bold text-amber-200">{s.t}</p>
                  <p className="text-sm text-amber-100/80 leading-6">{s.d}</p>
                </div>
              </li>
            ))}
          </ol>
        </section>

        {/* چه چیزهایی تازه است */}
        <section aria-label="امکانات جدید این نسخه" className="mt-6 rounded-2xl border border-amber-400/25 bg-black/25 p-5 text-sm text-amber-100/85 leading-7">
          <p className="font-display-fa text-lg text-amber-300 mb-2">تازه‌های نسخه ۰.۳ — ماشین‌های زبان‌باز! 🗯️</p>
          <ul className="list-disc list-inside space-y-1">
            <li>ماشین‌ها حرف می‌زنند! هر ماشین شخصیت، لقب و صدای مخصوص خودش را دارد — مثل انیمیشن‌های معروف ماشین‌ها</li>
            <li>بوقی شیطونِ محل است: لمسش کن تا با صدای شیطنتی بگوید «منو انتخاب کن!»</li>
            <li>بوست مخفی بوقی — سیستم طرف بوقی است! هر چند ثانیه نیتروش را خودش پر می‌کند 😎</li>
            <li>استاد فنر هم وسط کار آچار می‌زند و حرف می‌زند</li>
            <li>لوگوی رسمی بازی در منو + صدای لاله‌زبانِ زنده برای هر ۱۲ ماشین</li>
            <li>حباب‌های گفتار با افکت تایپ، جست‌وخیز و نفس‌کشیدن ماشین‌ها</li>
          </ul>
        </section>

        {/* اسکرین‌شات‌ها */}
        <section aria-label="تصاویر بازی" className="mt-8">
          <h2 className="font-display-fa text-2xl text-amber-300 mb-3 text-center">
            یک نگاه به بازی
          </h2>
          <div className="flex gap-3 overflow-x-auto pb-3 snap-x snap-mandatory rounded-2xl [-ms-overflow-style:none] [scrollbar-width:thin]">
            {SCREENSHOTS.map((s) => (
              <img
                key={s.src}
                src={s.src}
                alt={s.alt}
                className="snap-center shrink-0 w-[260px] sm:w-[320px] rounded-2xl border-2 border-amber-400/25 shadow-lg shadow-black/40"
              />
            ))}
          </div>
        </section>

        {/* یادداشت والدین */}
        <section className="mt-6 rounded-2xl border border-amber-400/15 bg-black/20 p-4 text-sm text-amber-100/75 leading-7">
          <p>
            <span className="font-bold text-amber-200">یادداشت برای والدین:</span>{" "}
            این نسخه تستِ داخلی است و بدون نیاز به حساب یا اینترنت بازی می‌شود.
            اگر چیزی به‌هم ریخت یا پیشنهادی داشتید، اسکرین‌شات بگیرید و برای ما
            بفرستید تا در نسخه بعد درستش کنیم.
          </p>
        </section>
      </div>

      <footer className="mt-auto w-full border-t border-amber-400/15 bg-black/30 py-4 text-center text-xs text-amber-200/60">
        بوقی: تور شهرها · نسخه تست ۰.۳.۰ · ساخته‌شده با ❤ برای بچه‌ها
      </footer>
    </main>
  );
}

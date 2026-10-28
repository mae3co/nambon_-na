-- 남이 본 나 · Supabase schema
-- Supabase 대시보드 > SQL Editor 에 통째로 붙여넣고 Run 하면 돼.
-- 구조: 결과는 공개. 로그인 없음. "답해야 결과 보기"는 화면에서 막는 규칙.

-- 1) 거울: 내가 만든 테스트 하나
create table public.mirrors (
  id           text primary key default substr(md5(random()::text || clock_timestamp()::text), 1, 8), -- 초대 링크에 들어가는 짧은 id
  name         text not null check (char_length(name) between 1 and 12),                             -- 질문에 들어갈 이름
  real_type    text check (real_type ~ '^[EI][SN][TF][JP]$'),                                         -- 진짜 4글자 (선택)
  self_answers text not null check (self_answers ~ '^[ab]{12}$'),                                     -- 내 답 12개
  created_at   timestamptz not null default now()
);

-- 2) 친구 답: 거울 하나에 여러 개
create table public.responses (
  id         uuid primary key default gen_random_uuid(),
  mirror_id  text not null references public.mirrors(id) on delete cascade,
  nickname   text not null check (char_length(btrim(nickname)) between 1 and 8),
  answers    text not null check (answers ~ '^[ab]{12}$'),
  created_at timestamptz not null default now(),
  unique (mirror_id, nickname)            -- 같은 거울에 같은 별명은 한 번만
);
create index responses_mirror_idx on public.responses (mirror_id, created_at);

-- 3) 장난 방지: 거울 하나당 친구 답은 최대 50개
create or replace function public.limit_responses()
returns trigger language plpgsql as $$
begin
  if (select count(*) from public.responses where mirror_id = new.mirror_id) >= 50 then
    raise exception 'too_many_responses';
  end if;
  return new;
end $$;
create trigger responses_limit before insert on public.responses
  for each row execute function public.limit_responses();

-- 4) 권한: "Automatically expose new tables"를 꺼뒀으니 필요한 것만 직접 열어줌
grant usage on schema public to anon;
grant select, insert on public.mirrors   to anon;
grant select, insert on public.responses to anon;

-- 5) RLS: 누구나 읽기·쓰기만 가능, 수정·삭제는 불가
alter table public.mirrors   enable row level security;
alter table public.responses enable row level security;

create policy "anyone reads mirrors"     on public.mirrors   for select to anon using (true);
create policy "anyone creates a mirror"  on public.mirrors   for insert to anon with check (true);
create policy "anyone reads responses"   on public.responses for select to anon using (true);
create policy "anyone answers a mirror"  on public.responses for insert to anon with check (true);
-- update / delete 정책은 일부러 안 만듦 → 아무도 못 고치고 못 지움

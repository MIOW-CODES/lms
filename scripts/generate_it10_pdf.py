#!/usr/bin/env python3
"""
Generate a complete, professional, publication-ready PDF for the
Table of Specifications (TOS) and Question Bank for the IT 10 course worksheets
(Quizzes 1–5 and the 1st Quarter Examination).
"""

import os
import re
import json
import base64
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

def load_all_data():
    # 1. Part 1 & Lab 1
    p1_file = REPO_ROOT / 'supabase/migrations/20261010000004_seed_it10_part1_lab1_quizzes.sql'
    with open(p1_file, 'r', encoding='utf-8') as f:
        content_p1 = f.read()

    quizzes = {}
    sections = re.split(r'UPDATE public\.quizzes SET deleted_at', content_p1)
    for sec in sections[1:]:
        title_m = re.search(r'VALUES \([^,]+,\s*\'([^\']+)\'', sec)
        if not title_m:
            continue
        title = title_m.group(1)
        tuples = re.findall(r'^\s*\(\s*(\d+)\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*\)', sec, re.MULTILINE)
        quizzes[title] = []
        for pos, q, opts, ans in tuples:
            q = q.replace("''", "'")
            ans = ans.replace("''", "'")
            try:
                options = json.loads(opts.replace("''", "'"))
            except:
                options = []
            quizzes[title].append({
                'pos': int(pos),
                'question': q,
                'options': options,
                'correct_answer': ans,
                'image_url': None,
                'lab_task': False,
                'required': False
            })

    # 2. Source quizzes: Part 2, Resistor Color Code, Programming with Arduino
    p2_file = REPO_ROOT / 'supabase/migrations/20261010000003_seed_it10_source_quizzes.sql'
    with open(p2_file, 'r', encoding='utf-8') as f:
        content_p2 = f.read()

    sections = re.split(r'UPDATE public\.quizzes SET deleted_at', content_p2)
    for sec in sections[1:]:
        title_m = re.search(r'VALUES \([^,]+,\s*\'([^\']+)\'', sec)
        if not title_m:
            continue
        title = title_m.group(1)
        tuples = re.findall(r'^\s*\(\s*(\d+)\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*\)', sec, re.MULTILINE)
        quizzes[title] = []
        for pos, q, opts, ans in tuples:
            q = q.replace("''", "'")
            ans = ans.replace("''", "'")
            try:
                options = json.loads(opts.replace("''", "'"))
            except:
                options = []
            quizzes[title].append({
                'pos': int(pos),
                'question': q,
                'options': options,
                'correct_answer': ans,
                'image_url': None,
                'lab_task': False,
                'required': False
            })

    # Add Part 2 lab tasks
    part2_lab_file = REPO_ROOT / 'supabase/migrations/20261010000008_quiz_part2_lab_tasks.sql'
    with open(part2_lab_file, 'r', encoding='utf-8') as f:
        part2_lab_content = f.read()
    
    lab_tasks = re.findall(r'\(\s*gen_random_uuid\(\),\s*v_quiz,\s*\'(.*?)\',\s*\'\[\]\'::jsonb,\s*\'(.*?)\',\s*(v_next(?:\s*\+\s*\d+)?),\s*NULL,\s*true,\s*true\s*\)', part2_lab_content, re.DOTALL)
    for q_task, ans_task, vpos in lab_tasks:
        pos = 25 if '+ 1' not in vpos else 26
        quizzes['Quiz — Arduino Part 2'].append({
            'pos': pos,
            'question': q_task.replace("''", "'"),
            'options': [],
            'correct_answer': ans_task.replace("''", "'"),
            'image_url': None,
            'lab_task': True,
            'required': True
        })

    # 3. Exam: 1st Quarter Exam
    exam_file = REPO_ROOT / 'supabase/migrations/20261010000002_seed_it10_exam.sql'
    with open(exam_file, 'r', encoding='utf-8') as f:
        exam_content = f.read()

    exam_tuples = re.findall(r'^\s*\(\s*(\d+)\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*\)', exam_content, re.MULTILINE)
    exam_items = []
    for pos, q, opts, ans in exam_tuples:
        q = q.replace("''", "'")
        ans = ans.replace("''", "'")
        try:
            options = json.loads(opts.replace("''", "'"))
        except:
            options = []
        exam_items.append({
            'pos': int(pos),
            'question': q,
            'options': options,
            'correct_answer': ans,
            'image_url': None,
            'lab_task': False,
            'required': False
        })
    
    # 4. Sim pics & Part IV for exam and resistor quiz
    sim_file = REPO_ROOT / 'supabase/migrations/20261010000005_it10_sim_pics_part_iv.sql'
    with open(sim_file, 'r', encoding='utf-8') as f:
        sim_content = f.read()

    sim_matches = re.findall(r'^\s*\(\s*(\d+)\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*,\s*\'(.*?)\'\s*,\s*(.*?)\s*\)', sim_content, re.MULTILINE)
    for pos_s, q_s, opts_s, ans_s, rest_s in sim_matches:
        pos = int(pos_s)
        q = q_s.replace("''", "'")
        ans = ans_s.replace("''", "'")
        img_url = None
        lab_task = False
        required = True
        if pos <= 75:
            m_img = re.search(r'\'(data:image/[^\']+)\'', rest_s)
            if m_img:
                img_url = m_img.group(1)
        else:
            lab_task = True
        
        exam_items.append({
            'pos': pos,
            'question': q,
            'options': [],
            'correct_answer': ans,
            'image_url': img_url,
            'lab_task': lab_task,
            'required': required
        })

    # Resistor SVGs on Exam
    exam_svgs = re.findall(r'UPDATE public\.quiz_questions SET image_url = \'(data:image/svg\+xml;base64,[^\']+)\'\s*WHERE quiz_id = v_exam AND position = (\d+);', sim_content)
    exam_svg_map = {int(p): url for url, p in exam_svgs}
    for item in exam_items:
        if item['pos'] in exam_svg_map:
            item['image_url'] = exam_svg_map[item['pos']]

    quizzes['1st Quarter Exam'] = sorted(exam_items, key=lambda x: x['pos'])

    # Resistor SVGs on Quiz — Resistor Color Code
    quiz_svgs = re.findall(r'UPDATE public\.quiz_questions SET image_url = \'(data:image/svg\+xml;base64,[^\']+)\'\s*WHERE quiz_id = v_quiz AND position = (\d+);', sim_content)
    quiz_svg_map = {int(p): url for url, p in quiz_svgs}
    for item in quizzes['Quiz — Resistor Color Code']:
        if item['pos'] in quiz_svg_map:
            item['image_url'] = quiz_svg_map[item['pos']]

    return quizzes

def determine_cognitive_level(title, pos, item):
    if item['lab_task']:
        return "Creating / Synthesis"
    if title == 'Quiz — Arduino Part 1':
        if pos in [6, 7, 9, 10, 11, 13, 14, 15, 20]:
            return "Remembering"
        elif pos in [1, 2, 3, 4, 5, 8, 16, 17, 18, 19, 21, 22]:
            return "Understanding"
        else:
            return "Applying"
    elif title == 'Quiz — Lab Activity 1 (Blinking LED)':
        if pos in [1, 2, 3, 4, 5, 11, 12, 13, 14]:
            return "Remembering"
        elif pos in [6, 7, 8, 9, 10, 15, 16, 20, 21, 22]:
            return "Understanding"
        else:
            return "Applying"
    elif title == 'Quiz — Arduino Part 2':
        if pos in [1, 8, 11, 13, 18, 19, 21, 22, 23, 24]:
            return "Remembering"
        elif pos in [2, 3, 4, 5, 6, 7, 10, 12, 14, 15, 16, 17, 20]:
            return "Understanding"
        elif pos in [25, 26]:
            return "Creating / Synthesis"
        else:
            return "Applying"
    elif title == 'Quiz — Resistor Color Code':
        if pos in [1, 2, 3, 4, 5, 6, 7, 20, 21, 22, 23]:
            return "Remembering"
        elif pos in [15, 16, 17, 24]:
            return "Understanding"
        else:
            return "Applying"
    elif title == 'Quiz — Programming with Arduino':
        if pos in [1, 2, 3, 7, 8, 13, 14, 23, 24]:
            return "Remembering"
        elif pos in [4, 5, 6, 9, 10, 11, 12, 16, 17, 18, 22]:
            return "Understanding"
        else:
            return "Applying"
    elif title == '1st Quarter Exam':
        if 1 <= pos <= 15:
            return "Applying / Analysis"
        elif 16 <= pos <= 25:
            return "Applying (Decoding)"
        elif 26 <= pos <= 35:
            return "Applying (Computation)"
        elif 36 <= pos <= 55:
            return "Remembering (Recall)"
        elif 56 <= pos <= 65:
            return "Understanding"
        elif 66 <= pos <= 75:
            return "Remembering (Visual ID)"
        elif 76 <= pos <= 77:
            return "Creating / Synthesis"
    return "Understanding"

def escape_html(text):
    if not text:
        return ""
    return (text
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace("'", '&#39;'))

def generate_html(quizzes):
    css = """
    @page {
      size: A4 portrait;
      margin: 16mm 14mm 16mm 14mm;
      @top-left {
        content: "MSU-IIT IDS • Information Technology 10";
        font-family: 'Fira Sans', 'DejaVu Sans', sans-serif;
        font-size: 7.5pt;
        color: #64748b;
      }
      @top-right {
        content: "Table of Specifications & Question Bank (Worksheets & Exam)";
        font-family: 'Fira Sans', 'DejaVu Sans', sans-serif;
        font-size: 7.5pt;
        color: #64748b;
      }
      @bottom-left {
        content: "Teacher: Alan L. Vergara • S.Y. 2026–2027";
        font-family: 'Fira Sans', 'DejaVu Sans', sans-serif;
        font-size: 7.5pt;
        color: #64748b;
      }
      @bottom-right {
        content: "Page " counter(page) " of " counter(pages);
        font-family: 'Fira Sans', 'DejaVu Sans', sans-serif;
        font-size: 8pt;
        font-weight: bold;
        color: #1e293b;
      }
    }

    * { box-sizing: border-box; }
    body {
      font-family: 'Fira Sans', 'DejaVu Sans', 'Liberation Sans', sans-serif;
      color: #1e293b;
      font-size: 9.5pt;
      line-height: 1.42;
      margin: 0;
      padding: 0;
    }

    .page-break { page-break-before: always; }
    .avoid-break { page-break-inside: avoid; }

    /* Cover Page */
    .cover {
      text-align: center;
      padding: 24px 10px 10px 10px;
    }
    .inst-header {
      border-bottom: 2px solid #334155;
      padding-bottom: 12px;
      margin-bottom: 24px;
    }
    .inst-header h4 {
      margin: 0 0 2px 0;
      font-size: 9.5pt;
      font-weight: 600;
      color: #475569;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .inst-header h2 {
      margin: 0 0 3px 0;
      font-size: 14pt;
      color: #0f172a;
      letter-spacing: 0.5px;
    }
    .inst-header h3 {
      margin: 0;
      font-size: 11pt;
      color: #4338ca;
      font-weight: 600;
    }

    .cover-title-box {
      background: linear-gradient(135deg, #f8fafc 0%, #ede9fe 100%);
      border: 1.5px solid #c4b5fd;
      border-radius: 8px;
      padding: 24px 18px;
      margin: 20px 0 24px 0;
    }
    .cover-title-box h1 {
      margin: 0 0 8px 0;
      font-size: 19pt;
      color: #3730a3;
      line-height: 1.25;
      letter-spacing: 0.3px;
    }
    .cover-title-box .subtitle {
      font-size: 12pt;
      font-weight: 600;
      color: #1e1b4b;
      margin-bottom: 6px;
    }
    .cover-title-box .track {
      font-size: 9.5pt;
      color: #475569;
    }

    .meta-table {
      width: 100%;
      border-collapse: collapse;
      margin: 16px 0 20px 0;
      font-size: 9pt;
      text-align: left;
    }
    .meta-table td {
      border: 1px solid #cbd5e1;
      padding: 6px 10px;
    }
    .meta-table td.label {
      background: #f1f5f9;
      font-weight: bold;
      color: #334155;
      width: 25%;
    }

    .summary-card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: 12px 14px;
      margin: 12px 0;
      text-align: left;
    }
    .summary-card h4 {
      margin: 0 0 6px 0;
      color: #1e293b;
      font-size: 10pt;
    }

    /* Headings */
    h2.section-header {
      font-size: 12.5pt;
      background: #1e293b;
      color: #ffffff;
      padding: 6px 10px;
      border-radius: 5px;
      margin: 18px 0 10px 0;
      letter-spacing: 0.3px;
    }
    h3.sub-header {
      font-size: 11pt;
      color: #3730a3;
      border-bottom: 1.5px solid #c7d2fe;
      padding-bottom: 4px;
      margin: 16px 0 8px 0;
    }

    /* Tables */
    table.tos-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 8pt;
      margin: 8px 0 14px 0;
      page-break-inside: avoid;
    }
    table.tos-table th {
      background: #312e81;
      color: #ffffff;
      border: 1px solid #312e81;
      padding: 5px 4px;
      text-align: center;
      font-weight: 600;
    }
    table.tos-table td {
      border: 1px solid #cbd5e1;
      padding: 4px 5px;
      text-align: center;
      vertical-align: middle;
    }
    table.tos-table td.left { text-align: left; }
    table.tos-table tr.total td {
      background: #e0e7ff;
      font-weight: bold;
      color: #1e1b4b;
    }
    table.tos-table tr:nth-child(even):not(.total) {
      background: #f8fafc;
    }

    /* Question Cards */
    .question-card {
      border: 1px solid #e2e8f0;
      border-left: 3.5px solid #4f46e5;
      background: #ffffff;
      border-radius: 4px;
      padding: 8px 10px;
      margin-bottom: 10px;
      page-break-inside: avoid;
    }
    .question-card.required {
      border-left-color: #dc2626;
      background: #fffafa;
    }
    .question-meta {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 4px;
      font-size: 7.5pt;
    }
    .badge {
      display: inline-block;
      padding: 1.5px 6px;
      border-radius: 9999px;
      font-size: 7.5pt;
      font-weight: 600;
    }
    .badge-primary { background: #e0e7ff; color: #3730a3; }
    .badge-success { background: #dcfce7; color: #166534; }
    .badge-danger { background: #fee2e2; color: #991b1b; }
    .badge-amber { background: #fef3c7; color: #92400e; }
    .badge-gray { background: #f1f5f9; color: #475569; }

    .q-text {
      font-size: 9.5pt;
      font-weight: 500;
      color: #0f172a;
      margin: 4px 0 6px 0;
    }
    .options-grid {
      display: grid;
      grid-template-columns: 1fr;
      gap: 3px;
      margin: 6px 0 6px 10px;
    }
    .option-item {
      font-size: 8.5pt;
      color: #334155;
    }
    .option-item.correct {
      color: #15803d;
      font-weight: 600;
    }
    .key-box {
      margin-top: 5px;
      padding: 4px 8px;
      background: #f0fdf4;
      border: 1px solid #bbf7d0;
      border-radius: 4px;
      font-size: 8pt;
      color: #166534;
    }
    .key-box strong { color: #14532d; }
    .rubric-box {
      margin-top: 5px;
      padding: 5px 8px;
      background: #fffbeb;
      border: 1px solid #fde68a;
      border-radius: 4px;
      font-size: 8pt;
      color: #92400e;
    }

    .q-media {
      text-align: center;
      margin: 6px 0;
    }
    .q-media img {
      max-height: 95px;
      max-width: 280px;
      border: 1px solid #cbd5e1;
      border-radius: 4px;
      background: #ffffff;
      padding: 2px;
    }

    /* Master Key Table */
    table.key-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 7.5pt;
      margin: 8px 0;
      page-break-inside: avoid;
    }
    table.key-table th {
      background: #0f766e;
      color: #ffffff;
      border: 1px solid #0f766e;
      padding: 4px 3px;
      text-align: center;
    }
    table.key-table td {
      border: 1px solid #99f6e4;
      padding: 3px 4px;
      text-align: left;
    }
    table.key-table td.center { text-align: center; font-weight: bold; }
    table.key-table tr:nth-child(even) { background: #f0fdfa; }

    /* Sign-off */
    .sign-table {
      width: 100%;
      margin-top: 30px;
      border-collapse: collapse;
      page-break-inside: avoid;
    }
    .sign-table td {
      width: 33.33%;
      padding: 24px 12px 4px 12px;
      vertical-align: bottom;
      text-align: center;
    }
    .sign-line {
      border-top: 1px solid #334155;
      padding-top: 4px;
      font-size: 8.5pt;
      font-weight: 600;
      color: #0f172a;
    }
    .sign-title {
      font-size: 7.5pt;
      color: #64748b;
    }
    """

    html = [f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>IT 10 — Table of Specifications & Question Bank</title>
<style>{css}</style>
</head>
<body>
"""]

    # 1. Cover Page
    html.append("""
    <div class="cover">
      <div class="inst-header">
        <h4>Republic of the Philippines</h4>
        <h2>MINDANAO STATE UNIVERSITY – ILIGAN INSTITUTE OF TECHNOLOGY</h2>
        <h3>INTEGRATED DEVELOPMENTAL SCHOOL</h3>
        <h4>Junior & Senior High School Department • Iligan City, Lanao del Norte</h4>
      </div>

      <div class="cover-title-box">
        <div class="subtitle">COURSE CURRICULAR ASSESSMENT DOCUMENT</div>
        <h1>TABLE OF SPECIFICATIONS (TOS) &amp; COMPLETE QUESTION BANK</h1>
        <div class="subtitle">Course Worksheets (Quizzes 1 to 5) and 1st Quarter Examination</div>
        <div class="track">Technical-Vocational-Livelihood (TVL) / ICT — Computer Systems Servicing &amp; Electronics</div>
      </div>

      <table class="meta-table">
        <tr>
          <td class="label">Course Title &amp; Code</td>
          <td><strong>Information Technology 10 (IT 10)</strong></td>
          <td class="label">Academic Term</td>
          <td><strong>First Quarter, S.Y. 2026–2027</strong></td>
        </tr>
        <tr>
          <td class="label">Subject Teacher</td>
          <td><strong>Alan L. Vergara</strong></td>
          <td class="label">Grade Level</td>
          <td><strong>Grade 10 (Junior High School)</strong></td>
        </tr>
        <tr>
          <td class="label">Assessment Delivery</td>
          <td><strong>MIOW LMS (Online Testing &amp; Virtual Arduino Lab)</strong></td>
          <td class="label">Curriculum Track</td>
          <td><strong>DepEd K to 12 TLE-ICT Electronics &amp; Microcontrollers</strong></td>
        </tr>
        <tr>
          <td class="label">Exam Bank Items</td>
          <td><strong>77 Items (50 drawn per attempt; 12 required)</strong></td>
          <td class="label">Worksheet Quizzes</td>
          <td><strong>5 Worksheets (24–26 items each, 122 total items)</strong></td>
        </tr>
        <tr>
          <td class="label">Total Question Bank</td>
          <td><strong>199 Authored Assessment Items with Keys &amp; Rubrics</strong></td>
          <td class="label">Cognitive Model</td>
          <td><strong>Bloom's Revised Taxonomy (DepEd Standards)</strong></td>
        </tr>
      </table>

      <div class="summary-card">
        <h4>Executive Summary &amp; Assessment Architecture</h4>
        <p style="margin:0 0 6px 0; font-size: 8.5pt; color: #334155;">
          This official curriculum assessment repository establishes the pedagogical alignment between instructional competencies,
          cognitive skill domains, and evaluation instruments for <strong>Information Technology 10</strong> at the MSU-IIT Integrated
          Developmental School. It encompasses both formative classroom worksheets (quizzes) and the summative 1st Quarter Examination.
        </p>
        <ul style="margin: 0; padding-left: 18px; font-size: 8.5pt; color: #334155;">
          <li><strong>Formative Worksheets (Quizzes 1–5):</strong> 10-minute timed assessments featuring randomized draws, SVG resistor diagrams, and rubric-scored Virtual Arduino Lab simulations.</li>
          <li><strong>Summative 1st Quarter Examination:</strong> 45-minute comprehensive exam utilizing a 77-item bank. Each student receives 50 items (12 mandatory items: 10 visual component identifications + 2 laboratory problem-solving tasks, plus 38 unseen-first items).</li>
          <li><strong>DepEd Alignment:</strong> Structured across Remembering (Recall), Understanding (Comprehension), Applying (Computation/Decoding), and Analyzing/Creating (Circuit Design &amp; Code Synthesis).</li>
        </ul>
      </div>

      <table class="sign-table" style="margin-top: 40px;">
        <tr>
          <td>
            <div class="sign-line">ALAN L. VERGARA</div>
            <div class="sign-title">Subject Teacher / Course Author</div>
          </td>
          <td>
            <div class="sign-line">DEPARTMENT HEAD / COORDINATOR</div>
            <div class="sign-title">Science &amp; Technology Department, IDS</div>
          </td>
          <td>
            <div class="sign-line">SCHOOL PRINCIPAL / DIRECTOR</div>
            <div class="sign-title">Integrated Developmental School, MSU-IIT</div>
          </td>
        </tr>
      </table>
    </div>
    """)

    # 2. Master Course TOS Blueprint
    html.append("""
    <div class="page-break"></div>
    <h2 class="section-header">SECTION 1: MASTER COURSE TABLE OF SPECIFICATIONS (TOS)</h2>
    <p style="font-size: 8.5pt; color: #475569; margin-top: -4px;">
      Master cognitive blueprint aggregating all instructional units, learning hours, item distributions,
      and percentage weights for IT 10 (First Quarter).
    </p>

    <table class="tos-table">
      <thead>
        <tr>
          <th rowspan="2" style="width: 24%;">Unit / Curricular Competency</th>
          <th rowspan="2" style="width: 7%;">Teaching<br>Hours</th>
          <th rowspan="2" style="width: 7%;">Weight<br>(%)</th>
          <th rowspan="2" style="width: 7%;">Total<br>Items</th>
          <th colspan="4">Cognitive Process Dimensions (Bloom's Revised Taxonomy)</th>
          <th rowspan="2" style="width: 15%;">Target Assessments / Delivery Mode</th>
        </tr>
        <tr>
          <th style="width: 8%;">Remembering</th>
          <th style="width: 8%;">Understanding</th>
          <th style="width: 8%;">Applying</th>
          <th style="width: 9%;">Analyzing / Creating</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="left"><strong>Unit 1: The Arduino Architecture &amp; Hardware</strong><br>
          <span style="color:#64748b;">ATmega328P microcontroller, digital/analog pins, power headers, USB, reset, bare minimum sketch structure.</span></td>
          <td>10</td>
          <td>25.0%</td>
          <td>48</td>
          <td>16</td>
          <td>22</td>
          <td>10</td>
          <td>0</td>
          <td class="left">Quiz — Arduino Part 1<br>Quiz — Arduino Part 2<br>Exam Domain A &amp; D</td>
        </tr>
        <tr>
          <td class="left"><strong>Unit 2: Prototyping &amp; Laboratory Wiring</strong><br>
          <span style="color:#64748b;">Solderless breadboards, jumper wires, LED polarity, current-limiting series resistors, safety precautions.</span></td>
          <td>6</td>
          <td>15.0%</td>
          <td>24</td>
          <td>8</td>
          <td>10</td>
          <td>6</td>
          <td>0</td>
          <td class="left">Quiz — Lab Activity 1<br>Exam Domain D</td>
        </tr>
        <tr>
          <td class="left"><strong>Unit 3: Resistor Color Codes &amp; Ohm's Law</strong><br>
          <span style="color:#64748b;">4-band and 5-band color charts, multipliers, gold/silver tolerances, Ohm's law (R = V/I) computations.</span></td>
          <td>8</td>
          <td>20.0%</td>
          <td>44</td>
          <td>11</td>
          <td>13</td>
          <td>20</td>
          <td>0</td>
          <td class="left">Quiz — Resistor Color Code<br>Exam Domain B &amp; C</td>
        </tr>
        <tr>
          <td class="left"><strong>Unit 4: Arduino C/C++ Programming &amp; I/O</strong><br>
          <span style="color:#64748b;">IDE setup, pinMode(), digitalWrite(), analogRead(), Serial Monitor baud rates, variables (int/float).</span></td>
          <td>8</td>
          <td>20.0%</td>
          <td>39</td>
          <td>10</td>
          <td>16</td>
          <td>13</td>
          <td>0</td>
          <td class="left">Quiz — Programming with Arduino<br>Exam Domain A</td>
        </tr>
        <tr>
          <td class="left"><strong>Unit 5: Visual Component Identification</strong><br>
          <span style="color:#64748b;">Physical identification of microcontrollers, breadboards, sensors, actuators, and hardware modules.</span></td>
          <td>4</td>
          <td>10.0%</td>
          <td>20</td>
          <td>15</td>
          <td>5</td>
          <td>0</td>
          <td>0</td>
          <td class="left">Exam Part I (Required visual photos)</td>
        </tr>
        <tr>
          <td class="left"><strong>Unit 6: Virtual Lab Simulation &amp; Synthesis</strong><br>
          <span style="color:#64748b;">Hands-on circuit construction on simulation canvas, code development, multi-LED traffic light, button I/O.</span></td>
          <td>4</td>
          <td>10.0%</td>
          <td>24</td>
          <td>2</td>
          <td>2</td>
          <td>6</td>
          <td>14</td>
          <td class="left">Quiz Part 2 Lab Tasks<br>Exam Part IV Problem Solving</td>
        </tr>
        <tr class="total">
          <td class="left">TOTAL CURRICULAR BANK</td>
          <td>40 hrs</td>
          <td>100.0%</td>
          <td>199</td>
          <td>62 (31.2%)</td>
          <td>68 (34.2%)</td>
          <td>55 (27.6%)</td>
          <td>14 (7.0%)</td>
          <td class="left">All 5 Quizzes + 1st Quarter Exam</td>
        </tr>
      </tbody>
    </table>

    <div class="summary-card">
      <h4>Assessment Administration &amp; Test Security Policy</h4>
      <p style="font-size: 8.5pt; color: #334155; margin: 0 0 4px 0;">
        Under the approved IT 10 assessment guidelines (SY 2026–2027), all examinations and quizzes adhere to the following execution protocols:
      </p>
      <ul style="font-size: 8.5pt; color: #334155; margin: 0; padding-left: 18px;">
        <li><strong>Fixed Window Gating:</strong> Assessments open strictly within scheduled timeframes (e.g., Friday 08:00–10:00 Asia/Manila). Submissions outside the window are server-blocked.</li>
        <li><strong>Randomized Unseen-First Draw:</strong> Each quiz draws a fresh 20-item subset from its authored bank, while the exam draws 50 items (12 mandatory + 38 randomized), guaranteeing integrity.</li>
        <li><strong>Grading &amp; Review Policy:</strong> Immediate score visibility upon submission; answer keys and detailed explanations are withheld until official teacher release.</li>
      </ul>
    </div>
    """)

    # 3. Individual TOS
    html.append("""
    <div class="page-break"></div>
    <h2 class="section-header">SECTION 2: INDIVIDUAL WORKSHEET &amp; EXAMINATION TABLES OF SPECIFICATIONS</h2>
    <p style="font-size: 8.5pt; color: #475569; margin-top: -4px;">
      Detailed DepEd-format Table of Specifications for each individual course worksheet (quiz) and the 1st Quarter Examination.
    </p>

    <!-- TOS 1: Arduino Part 1 -->
    <h3 class="sub-header">Worksheet 1: Quiz — Arduino Part 1 (24 Items)</h3>
    <table class="tos-table">
      <thead>
        <tr>
          <th style="width:30%;">Topic / Competency</th>
          <th style="width:8%;">Items</th>
          <th style="width:8%;">%</th>
          <th style="width:11%;">Remembering</th>
          <th style="width:11%;">Understanding</th>
          <th style="width:11%;">Applying</th>
          <th style="width:21%;">Item Numbers</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="left">A. Arduino Uno Board &amp; Microcontroller Architecture</td>
          <td>12</td>
          <td>50%</td>
          <td>7</td>
          <td>4</td>
          <td>1</td>
          <td>1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12</td>
        </tr>
        <tr>
          <td class="left">B. Circuit Components &amp; Beginner Boards (Nano/Mega, Breadboard, LED, Pushbutton)</td>
          <td>12</td>
          <td>50%</td>
          <td>5</td>
          <td>4</td>
          <td>3</td>
          <td>13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24</td>
        </tr>
        <tr class="total">
          <td class="left">TOTAL</td>
          <td>24</td>
          <td>100%</td>
          <td>12 (50.0%)</td>
          <td>8 (33.3%)</td>
          <td>4 (16.7%)</td>
          <td>Items 1–24</td>
        </tr>
      </tbody>
    </table>

    <!-- TOS 2: Lab Activity 1 -->
    <h3 class="sub-header">Worksheet 2: Quiz — Lab Activity 1: Blinking LED (24 Items)</h3>
    <table class="tos-table">
      <thead>
        <tr>
          <th style="width:30%;">Topic / Competency</th>
          <th style="width:8%;">Items</th>
          <th style="width:8%;">%</th>
          <th style="width:11%;">Remembering</th>
          <th style="width:11%;">Understanding</th>
          <th style="width:11%;">Applying</th>
          <th style="width:21%;">Item Numbers</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="left">A. Circuit Assembly, Series Limiting Resistor &amp; Hardware Safety</td>
          <td>10</td>
          <td>41.7%</td>
          <td>4</td>
          <td>4</td>
          <td>2</td>
          <td>1, 2, 3, 4, 5, 6, 7, 8, 9, 10</td>
        </tr>
        <tr>
          <td class="left">B. Arduino IDE Workflow, Blink Sketch Syntax &amp; Timing Logic</td>
          <td>14</td>
          <td>58.3%</td>
          <td>4</td>
          <td>6</td>
          <td>4</td>
          <td>11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24</td>
        </tr>
        <tr class="total">
          <td class="left">TOTAL</td>
          <td>24</td>
          <td>100%</td>
          <td>8 (33.3%)</td>
          <td>10 (41.7%)</td>
          <td>6 (25.0%)</td>
          <td>Items 1–24</td>
        </tr>
      </tbody>
    </table>

    <!-- TOS 3: Arduino Part 2 -->
    <h3 class="sub-header">Worksheet 3: Quiz — Arduino Part 2 (26 Items)</h3>
    <table class="tos-table">
      <thead>
        <tr>
          <th style="width:28%;">Topic / Competency</th>
          <th style="width:7%;">Items</th>
          <th style="width:7%;">%</th>
          <th style="width:10%;">Remember</th>
          <th style="width:10%;">Understand</th>
          <th style="width:10%;">Apply</th>
          <th style="width:10%;">Create</th>
          <th style="width:18%;">Item Numbers</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="left">A. Open-Source Prototyping, Bare Minimum &amp; Libraries</td>
          <td>9</td>
          <td>34.6%</td>
          <td>3</td>
          <td>5</td>
          <td>1</td>
          <td>0</td>
          <td>1, 2, 3, 4, 5, 6, 7, 8, 9</td>
        </tr>
        <tr>
          <td class="left">B. Sensors, Actuators &amp; Single-Board Computers</td>
          <td>11</td>
          <td>42.3%</td>
          <td>5</td>
          <td>4</td>
          <td>2</td>
          <td>0</td>
          <td>10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20</td>
        </tr>
        <tr>
          <td class="left">C. Traffic Light Assessment &amp; Circuit Simulation</td>
          <td>4</td>
          <td>15.4%</td>
          <td>1</td>
          <td>1</td>
          <td>2</td>
          <td>0</td>
          <td>21, 22, 23, 24</td>
        </tr>
        <tr>
          <td class="left">D. Virtual Arduino Lab Simulation Tasks (Traffic Light &amp; Button LED)</td>
          <td>2</td>
          <td>7.7%</td>
          <td>0</td>
          <td>0</td>
          <td>0</td>
          <td>2</td>
          <td>25, 26 (Required Tasks)</td>
        </tr>
        <tr class="total">
          <td class="left">TOTAL</td>
          <td>26</td>
          <td>100%</td>
          <td>9 (34.6%)</td>
          <td>10 (38.5%)</td>
          <td>5 (19.2%)</td>
          <td>2 (7.7%)</td>
          <td>Items 1–26</td>
        </tr>
      </tbody>
    </table>

    <div class="page-break"></div>
    <!-- TOS 4: Resistor Color Code -->
    <h3 class="sub-header">Worksheet 4: Quiz — Resistor Color Code (24 Items)</h3>
    <table class="tos-table">
      <thead>
        <tr>
          <th style="width:30%;">Topic / Competency</th>
          <th style="width:8%;">Items</th>
          <th style="width:8%;">%</th>
          <th style="width:11%;">Remembering</th>
          <th style="width:11%;">Understanding</th>
          <th style="width:11%;">Applying</th>
          <th style="width:21%;">Item Numbers</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="left">A. 4-Band Resistor Reading Rules, Multipliers &amp; Tolerances</td>
          <td>10</td>
          <td>41.7%</td>
          <td>5</td>
          <td>3</td>
          <td>2</td>
          <td>1, 2, 3, 4, 5, 6, 7, 8, 9, 10</td>
        </tr>
        <tr>
          <td class="left">B. Resistance Value Decoding (4-Band Calculations)</td>
          <td>4</td>
          <td>16.7%</td>
          <td>0</td>
          <td>1</td>
          <td>3</td>
          <td>11, 12, 13, 14</td>
        </tr>
        <tr>
          <td class="left">C. 5-Band Precision Resistors (Significant Digits &amp; Tolerances)</td>
          <td>5</td>
          <td>20.8%</td>
          <td>1</td>
          <td>2</td>
          <td>2</td>
          <td>15, 16, 17, 18, 19</td>
        </tr>
        <tr>
          <td class="left">D. Resistor Color Principles &amp; Multimeter Verification</td>
          <td>5</td>
          <td>20.8%</td>
          <td>1</td>
          <td>3</td>
          <td>1</td>
          <td>20, 21, 22, 23, 24</td>
        </tr>
        <tr class="total">
          <td class="left">TOTAL</td>
          <td>24</td>
          <td>100%</td>
          <td>7 (29.2%)</td>
          <td>9 (37.5%)</td>
          <td>8 (33.3%)</td>
          <td>Items 1–24</td>
        </tr>
      </tbody>
    </table>

    <!-- TOS 5: Programming with Arduino -->
    <h3 class="sub-header">Worksheet 5: Quiz — Programming with Arduino (24 Items)</h3>
    <table class="tos-table">
      <thead>
        <tr>
          <th style="width:30%;">Topic / Competency</th>
          <th style="width:8%;">Items</th>
          <th style="width:8%;">%</th>
          <th style="width:11%;">Remembering</th>
          <th style="width:11%;">Understanding</th>
          <th style="width:11%;">Applying</th>
          <th style="width:21%;">Item Numbers</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="left">A. Course Guide Structure, Short Circuits &amp; Breadboard Safety</td>
          <td>6</td>
          <td>25.0%</td>
          <td>3</td>
          <td>2</td>
          <td>1</td>
          <td>1, 2, 3, 4, 5, 6</td>
        </tr>
        <tr>
          <td class="left">B. IDE Environment, Verification, Uploading &amp; Serial Monitor</td>
          <td>6</td>
          <td>25.0%</td>
          <td>2</td>
          <td>3</td>
          <td>1</td>
          <td>7, 8, 9, 10, 11, 12</td>
        </tr>
        <tr>
          <td class="left">C. Digital &amp; Analog I/O Functions (digitalWrite/Read, analogRead/Write)</td>
          <td>6</td>
          <td>25.0%</td>
          <td>1</td>
          <td>3</td>
          <td>2</td>
          <td>13, 14, 15, 16, 17, 18</td>
        </tr>
        <tr>
          <td class="left">D. Sensor Interfacing &amp; C/C++ Data Types (int, float, LDR, TMP36)</td>
          <td>6</td>
          <td>25.0%</td>
          <td>2</td>
          <td>3</td>
          <td>1</td>
          <td>19, 20, 21, 22, 23, 24</td>
        </tr>
        <tr class="total">
          <td class="left">TOTAL</td>
          <td>24</td>
          <td>100%</td>
          <td>8 (33.3%)</td>
          <td>11 (45.8%)</td>
          <td>5 (20.8%)</td>
          <td>Items 1–24</td>
        </tr>
      </tbody>
    </table>

    <!-- TOS EXAM: 1st Quarter Examination -->
    <h3 class="sub-header">Summative Examination: 1st Quarter Examination (77 Items)</h3>
    <p style="font-size: 8pt; color: #475569; margin: -2px 0 6px 0;">
      Official 77-item question bank blueprint. Each student attempt draws 50 items: 12 mandatory items (Part I visual identification + Part IV lab tasks) + 38 unseen-first items from Domains A–D.
    </p>
    <table class="tos-table">
      <thead>
        <tr>
          <th style="width:8%;">Domain</th>
          <th style="width:28%;">Content / Learning Competency</th>
          <th style="width:16%;">Cognitive Skill</th>
          <th style="width:8%;">Bank Items</th>
          <th style="width:8%;">% Bank</th>
          <th style="width:10%;">Per Attempt</th>
          <th style="width:22%;">Item Number Range</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Domain A</strong></td>
          <td class="left">Arduino Programming Fundamentals (code constructs, setup/loop, pin modes, delay, I/O)</td>
          <td>Application / Analysis</td>
          <td>25</td>
          <td>32.5%</td>
          <td>~14 (of 38)</td>
          <td>Items 1–15, 56–65</td>
        </tr>
        <tr>
          <td><strong>Domain B</strong></td>
          <td class="left">Resistor Color Code (4-band decoding with band diagrams)</td>
          <td>Application / Decoding</td>
          <td>10</td>
          <td>13.0%</td>
          <td>~6 (of 38)</td>
          <td>Items 16–25</td>
        </tr>
        <tr>
          <td><strong>Domain C</strong></td>
          <td class="left">Resistance Value Computation (Ohm's Law: R = V/I)</td>
          <td>Application / Computation</td>
          <td>10</td>
          <td>13.0%</td>
          <td>~6 (of 38)</td>
          <td>Items 26–35</td>
        </tr>
        <tr>
          <td><strong>Domain D</strong></td>
          <td class="left">Arduino Family &amp; SIK Components (Hardware Identification)</td>
          <td>Knowledge / Recall</td>
          <td>20</td>
          <td>26.0%</td>
          <td>~12 (of 38)</td>
          <td>Items 36–55</td>
        </tr>
        <tr style="background: #fff1f2;">
          <td><strong>Part I</strong></td>
          <td class="left">Visual Component Identification (Real photograph matching)</td>
          <td>Knowledge / Recall (Visual)</td>
          <td>10</td>
          <td>13.0%</td>
          <td><strong>10 (Required)</strong></td>
          <td>Items 66–75 (All attempts)</td>
        </tr>
        <tr style="background: #fff1f2;">
          <td><strong>Part IV</strong></td>
          <td class="left">Problem Solving in Virtual Arduino Lab (Circuit wiring + Sketch coding)</td>
          <td>Analysis / Synthesis (Rubric)</td>
          <td>2</td>
          <td>2.6%</td>
          <td><strong>2 (Required)</strong></td>
          <td>Items 76–77 (All attempts)</td>
        </tr>
        <tr class="total">
          <td colspan="2" class="left">TOTAL 1st QUARTER EXAMINATION</td>
          <td>Comprehensive</td>
          <td>77</td>
          <td>100.0%</td>
          <td>50 Items Drawn</td>
          <td>Items 1–77</td>
        </tr>
      </tbody>
    </table>
    """)

    # 4. Question Banks
    html.append("""
    <div class="page-break"></div>
    <h2 class="section-header">SECTION 3: COMPLETE QUESTION BANK WITH ANSWER KEYS &amp; RUBRICS</h2>
    <p style="font-size: 8.5pt; color: #475569; margin-top: -4px;">
      Exhaustive question bank covering all 5 course worksheets and the 1st Quarter Examination. Includes full question stems,
      diagrams, answer options, keyed responses, accepted variants, and scoring rubrics.
    </p>
    """)

    quiz_keys = [
        ('Quiz — Arduino Part 1', 'Worksheet 1: Quiz — Arduino Part 1 (24 Items)'),
        ('Quiz — Lab Activity 1 (Blinking LED)', 'Worksheet 2: Quiz — Lab Activity 1: Blinking LED (24 Items)'),
        ('Quiz — Arduino Part 2', 'Worksheet 3: Quiz — Arduino Part 2 (26 Items)'),
        ('Quiz — Resistor Color Code', 'Worksheet 4: Quiz — Resistor Color Code (24 Items)'),
        ('Quiz — Programming with Arduino', 'Worksheet 5: Quiz — Programming with Arduino (24 Items)'),
        ('1st Quarter Exam', 'Summative Assessment: 1st Quarter Examination (77 Items)'),
    ]

    for qk, qtitle in quiz_keys:
        items = quizzes[qk]
        html.append(f"""
        <div class="page-break"></div>
        <h3 class="sub-header" style="font-size: 12pt; color: #1e1b4b; background: #e0e7ff; padding: 6px 10px; border-radius: 4px; border-bottom: 2px solid #6366f1;">
          {escape_html(qtitle)}
        </h3>
        """)

        for item in items:
            pos = item['pos']
            cog = determine_cognitive_level(qk, pos, item)
            is_req = item['required']
            card_class = "question-card required" if is_req else "question-card"
            badge_type = '<span class="badge badge-danger">Required</span>' if is_req else ''
            
            pts = "1 pt"
            if qk == '1st Quarter Exam' and pos == 76:
                pts = "5 pts (Lab Sketch)"
            elif qk == '1st Quarter Exam' and pos == 77:
                pts = "10 pts (Lab Circuit)"
            elif qk == 'Quiz — Arduino Part 2' and pos in [25, 26]:
                pts = "5 pts (Simulation)"

            html.append(f"""
            <div class="{card_class}">
              <div class="question-meta">
                <div>
                  <strong style="color:#1e1b4b; font-size: 8.5pt;">Item #{pos}</strong>
                  <span class="badge badge-primary">{escape_html(cog)}</span>
                  <span class="badge badge-gray">{pts}</span>
                  {badge_type}
                </div>
              </div>
              <div class="q-text">{escape_html(item['question'])}</div>
            """)

            if item['image_url']:
                html.append(f"""
                <div class="q-media">
                  <img src="{item['image_url']}" alt="Item Diagram / Visual" />
                </div>
                """)

            if item['options'] and len(item['options']) > 0:
                html.append('<div class="options-grid">')
                labels = ['A', 'B', 'C', 'D', 'E']
                for idx, opt in enumerate(item['options']):
                    lbl = labels[idx] if idx < len(labels) else f"({idx+1})"
                    is_correct = (opt.strip() == item['correct_answer'].strip())
                    opt_class = "option-item correct" if is_correct else "option-item"
                    checkmark = " ✓ (Correct)" if is_correct else ""
                    html.append(f'<div class="{opt_class}"><strong>{lbl}.</strong> {escape_html(opt)}{checkmark}</div>')
                html.append('</div>')

            # Key or Rubric
            ans = item['correct_answer']
            if ans.startswith('Rubric:'):
                html.append(f"""
                <div class="rubric-box">
                  <strong>Analytic Scoring Rubric:</strong><br>
                  {escape_html(ans)}
                </div>
                """)
            elif '||' in ans:
                variants = " &nbsp;|&nbsp; ".join([f"<code>{escape_html(v)}</code>" for v in ans.split('||')])
                html.append(f"""
                <div class="key-box">
                  <strong>Accepted Identification Key Variants:</strong> {variants}
                </div>
                """)
            elif not item['options']:
                html.append(f"""
                <div class="key-box">
                  <strong>Answer Key:</strong> <code>{escape_html(ans)}</code>
                </div>
                """)

            html.append('</div>')

    # 5. Master Quick-Reference Answer Key
    html.append("""
    <div class="page-break"></div>
    <h2 class="section-header">SECTION 4: CONSOLIDATED MASTER ANSWER KEY</h2>
    <p style="font-size: 8.5pt; color: #475569; margin-top: -4px;">
      Quick-reference verification matrix for instructors, proctors, and examiners.
    </p>
    """)

    for qk, qtitle in quiz_keys:
        items = quizzes[qk]
        html.append(f"""
        <h3 class="sub-header" style="font-size: 10pt; margin-top: 12px; margin-bottom: 4px;">{escape_html(qtitle)}</h3>
        <table class="key-table">
          <thead>
            <tr>
              <th style="width: 8%;">#</th>
              <th style="width: 42%;">Correct Answer / Key</th>
              <th style="width: 8%;">#</th>
              <th style="width: 42%;">Correct Answer / Key</th>
            </tr>
          </thead>
          <tbody>
        """)

        half = (len(items) + 1) // 2
        for r in range(half):
            it1 = items[r]
            it2 = items[r + half] if (r + half) < len(items) else None
            
            ans1 = it1['correct_answer']
            if ans1.startswith('Rubric:'):
                ans1 = ans1[:50] + "..."
            elif '||' in ans1:
                ans1 = ans1.split('||')[0] + " (or variants)"

            col2_num = f"{it2['pos']}" if it2 else ""
            if it2:
                ans2 = it2['correct_answer']
                if ans2.startswith('Rubric:'):
                    ans2 = ans2[:50] + "..."
                elif '||' in ans2:
                    ans2 = ans2.split('||')[0] + " (or variants)"
            else:
                ans2 = ""

            html.append(f"""
            <tr>
              <td class="center">{it1['pos']}</td>
              <td>{escape_html(ans1)}</td>
              <td class="center">{col2_num}</td>
              <td>{escape_html(ans2)}</td>
            </tr>
            """)
        html.append('</tbody></table>')

    # Signature Block at End
    html.append("""
    <div class="avoid-break" style="margin-top: 24px; padding-top: 16px; border-top: 1.5px solid #cbd5e1;">
      <table class="sign-table" style="margin-top: 0;">
        <tr>
          <td>
            <div class="sign-line">ALAN L. VERGARA</div>
            <div class="sign-title">Subject Teacher / Course Specialist</div>
          </td>
          <td>
            <div class="sign-line">DEPARTMENT HEAD / COORDINATOR</div>
            <div class="sign-title">Science &amp; Technology Department, IDS</div>
          </td>
          <td>
            <div class="sign-line">SCHOOL PRINCIPAL / DIRECTOR</div>
            <div class="sign-title">Integrated Developmental School, MSU-IIT</div>
          </td>
        </tr>
      </table>
      <div style="text-align: center; font-size: 7.5pt; color: #94a3b8; margin-top: 16px;">
        Generated for MSU-IIT IDS Online Workspace (MIOW LMS) • Document Version 2.4 • First Quarter S.Y. 2026–2027
      </div>
    </div>
    </body>
    </html>
    """)

    return "\n".join(html)

def main():
    print("1. Extracting questions and metadata from SQL migrations...")
    quizzes = load_all_data()

    print("2. Generating HTML document with DepEd TOS tables and complete Question Bank...")
    html_content = generate_html(quizzes)
    
    html_path = REPO_ROOT / 'docs/IT10/it10-tos-and-question-bank.html'
    html_path.parent.mkdir(parents=True, exist_ok=True)
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html_content)
    print(f"   HTML written to: {html_path} ({len(html_content)} bytes)")

    # Output PDF targets
    pdf_targets = [
        REPO_ROOT / 'docs/IT10/IT10-TOS-and-Question-Bank.pdf',
        REPO_ROOT / 'materials-it10/IT 10 - TOS and Question Bank (Quizzes and Exam).pdf',
        REPO_ROOT / 'IT10-TOS-and-Question-Bank.pdf'
    ]

    primary_pdf = pdf_targets[0]
    primary_pdf.parent.mkdir(parents=True, exist_ok=True)

    print(f"3. Rendering PDF via Chromium headless to: {primary_pdf}...")
    cmd = [
        'chromium',
        '--headless',
        '--no-sandbox',
        '--disable-gpu',
        '--run-all-compositor-stages-before-draw',
        f'--print-to-pdf={primary_pdf}',
        '--virtual-time-budget=5000',
        f'file://{html_path.resolve()}'
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        print("Chromium error:", res.stderr)
        raise RuntimeError(f"Chromium failed with code {res.returncode}")

    size = os.path.getsize(primary_pdf)
    print(f"   Primary PDF generated: {primary_pdf} ({size} bytes)")

    # Copy to other targets
    import shutil
    for target in pdf_targets[1:]:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(primary_pdf, target)
        print(f"   Copied to: {target}")

    print("Done! PDF generation completed successfully.")

if __name__ == '__main__':
    main()
